package services

import (
	"context"
	"database/sql"
	"encoding/json"
	"time"

	"climatetech-backend/internal/models"

	"github.com/go-redis/redis/v8"
	"gorm.io/gorm"
)

// AllCommodityTypes lists the real tradeable commodities the price index
// covers -- models.CommodityOther is excluded since it's a catch-all
// bucket for generic listings, not a distinct market.
var AllCommodityTypes = []models.CommodityType{
	models.CommodityCoal,
	models.CommodityBiomass,
	models.CommodityCoke,
	models.CommodityCarbonCredit,
}

const priceIndexCacheTTL = time.Hour

// PriceBand is average/min/max price for one commodity within one unit of
// measurement. Prices are never blended across units (a "price per ton"
// figure and a "price per kg" figure aren't comparable), so a commodity
// with listings in more than one unit shows up as multiple bands rather
// than one misleading combined average.
type PriceBand struct {
	Unit       string  `json:"unit"`
	AvgPrice   float64 `json:"avg_price"`
	MinPrice   float64 `json:"min_price"`
	MaxPrice   float64 `json:"max_price"`
	SampleSize int64   `json:"sample_size"`
}

// LiveIndex is the current price picture for one commodity: ListingBands
// reflects what sellers are currently asking (active Listings), while
// TransactedBands reflects what buyers actually paid in the last 30 days
// (non-cancelled Orders) -- a more meaningful "market price" signal than
// asking prices alone, shown alongside rather than instead of them.
type LiveIndex struct {
	CommodityType   string      `json:"commodity_type"`
	ListingBands    []PriceBand `json:"listing_bands"`
	TransactedBands []PriceBand `json:"transacted_bands"`
	ComputedAt      time.Time   `json:"computed_at"`
}

// PriceIndexService takes its DB/Redis handles via constructor injection
// rather than importing internal/database directly -- internal/database
// (specifically seed.go) already imports internal/services for seeding
// data via GeminiService, so services importing internal/database back
// would create an import cycle. Callers pass database.DB / database.RedisClient
// from wherever they already have them (see routes.go and cmd/server/main.go).
type PriceIndexService struct {
	db    *gorm.DB
	redis *redis.Client
}

func NewPriceIndexService(db *gorm.DB, redisClient *redis.Client) *PriceIndexService {
	return &PriceIndexService{db: db, redis: redisClient}
}

// GetLiveIndex returns the cached index for commodityType if a fresh one
// exists (Redis, priceIndexCacheTTL), otherwise recomputes it from the
// database and refreshes the cache.
func (s *PriceIndexService) GetLiveIndex(commodityType models.CommodityType) (*LiveIndex, error) {
	ctx := context.Background()
	cacheKey := "price_index:" + string(commodityType)

	if cached, err := s.redis.Get(ctx, cacheKey).Result(); err == nil {
		var index LiveIndex
		if jsonErr := json.Unmarshal([]byte(cached), &index); jsonErr == nil {
			return &index, nil
		}
		// Falls through to recompute on a corrupt/unexpected cache entry
		// rather than failing the request over it.
	}

	index, err := s.computeLiveIndex(commodityType)
	if err != nil {
		return nil, err
	}

	if data, err := json.Marshal(index); err == nil {
		// Caching is a performance optimization, not a correctness
		// requirement -- a Redis write failure here shouldn't fail the
		// request when the freshly computed data is already in hand.
		s.redis.Set(ctx, cacheKey, data, priceIndexCacheTTL)
	}

	return index, nil
}

// GetAllLiveIndexes returns the live index for every commodity in
// AllCommodityTypes, in one call.
func (s *PriceIndexService) GetAllLiveIndexes() ([]*LiveIndex, error) {
	indexes := make([]*LiveIndex, 0, len(AllCommodityTypes))
	for _, ct := range AllCommodityTypes {
		index, err := s.GetLiveIndex(ct)
		if err != nil {
			return nil, err
		}
		indexes = append(indexes, index)
	}
	return indexes, nil
}

func (s *PriceIndexService) computeLiveIndex(commodityType models.CommodityType) (*LiveIndex, error) {
	listingBands, err := s.priceBandsFromListings(commodityType)
	if err != nil {
		return nil, err
	}
	transactedBands, err := s.priceBandsFromOrders(commodityType)
	if err != nil {
		return nil, err
	}

	return &LiveIndex{
		CommodityType:   string(commodityType),
		ListingBands:    listingBands,
		TransactedBands: transactedBands,
		ComputedAt:      time.Now(),
	}, nil
}

// priceBandRow mirrors the aggregate query's column set. Avg/Min/Max use
// sql.NullFloat64 because AVG/MIN/MAX return SQL NULL (not zero) for a unit
// with zero matching rows -- scanning NULL into a plain float64 would error.
type priceBandRow struct {
	Unit  string
	Avg   sql.NullFloat64
	Min   sql.NullFloat64
	Max   sql.NullFloat64
	Count int64
}

// priceBandsFromListings computes per-unit price bands from currently
// active listings -- "what sellers are asking right now".
func (s *PriceIndexService) priceBandsFromListings(commodityType models.CommodityType) ([]PriceBand, error) {
	var rows []priceBandRow
	err := s.db.Model(&models.Listing{}).
		Select("unit, AVG(price) as avg, MIN(price) as min, MAX(price) as max, COUNT(*) as count").
		Where("commodity_type = ? AND is_active = ?", commodityType, true).
		Group("unit").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	return rowsToBands(rows), nil
}

// priceBandsFromOrders computes per-unit price bands from orders placed in
// the last 30 days, excluding cancelled ones -- "what buyers actually
// paid", as distinct from priceBandsFromListings' asking prices.
func (s *PriceIndexService) priceBandsFromOrders(commodityType models.CommodityType) ([]PriceBand, error) {
	var rows []priceBandRow
	cutoff := time.Now().AddDate(0, 0, -30)
	err := s.db.Model(&models.Order{}).
		Select("unit, AVG(price_per_unit) as avg, MIN(price_per_unit) as min, MAX(price_per_unit) as max, COUNT(*) as count").
		Where("commodity_type = ? AND status != ? AND created_at >= ?", commodityType, models.OrderStatusCancelled, cutoff).
		Group("unit").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	return rowsToBands(rows), nil
}

func rowsToBands(rows []priceBandRow) []PriceBand {
	bands := make([]PriceBand, 0, len(rows))
	for _, r := range rows {
		if r.Count == 0 || !r.Avg.Valid {
			continue
		}
		bands = append(bands, PriceBand{
			Unit:       r.Unit,
			AvgPrice:   r.Avg.Float64,
			MinPrice:   r.Min.Float64,
			MaxPrice:   r.Max.Float64,
			SampleSize: r.Count,
		})
	}
	return bands
}

// RecordDailySnapshot persists today's live index (per commodity, per unit,
// per source) as PriceIndexSnapshot rows, for later charting via
// PriceIndexHandler.GetPriceHistory. Called both by the admin-triggered
// manual endpoint and the background ticker in cmd/server/main.go. Bypasses
// the Redis cache -- a snapshot should reflect current data, not a
// potentially-stale cached read. Bands with zero samples are skipped
// rather than recorded as a misleading zero.
func (s *PriceIndexService) RecordDailySnapshot() error {
	now := time.Now()
	for _, ct := range AllCommodityTypes {
		index, err := s.computeLiveIndex(ct)
		if err != nil {
			return err
		}
		if err := s.saveSnapshotBands(ct, "listing", index.ListingBands, now); err != nil {
			return err
		}
		if err := s.saveSnapshotBands(ct, "transacted", index.TransactedBands, now); err != nil {
			return err
		}
	}
	return nil
}

func (s *PriceIndexService) saveSnapshotBands(commodityType models.CommodityType, source string, bands []PriceBand, recordedAt time.Time) error {
	for _, b := range bands {
		snapshot := models.PriceIndexSnapshot{
			CommodityType: commodityType,
			Unit:          b.Unit,
			Source:        source,
			AvgPrice:      b.AvgPrice,
			MinPrice:      b.MinPrice,
			MaxPrice:      b.MaxPrice,
			SampleSize:    int(b.SampleSize),
			RecordedAt:    recordedAt,
		}
		if err := s.db.Create(&snapshot).Error; err != nil {
			return err
		}
	}
	return nil
}
