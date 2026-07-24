package handlers

import (
	"net/http"
	"strconv"
	"time"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/services"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type PriceIndexHandler struct {
	service *services.PriceIndexService
}

func NewPriceIndexHandler(service *services.PriceIndexService) *PriceIndexHandler {
	return &PriceIndexHandler{service: service}
}

func isValidIndexCommodity(commodityType string) bool {
	for _, ct := range services.AllCommodityTypes {
		if string(ct) == commodityType {
			return true
		}
	}
	return false
}

// GetPriceIndex returns the live price index (asking-price and
// actual-transacted bands, grouped by unit -- see services.PriceBand) for
// one commodity type.
// GET /api/v1/marketplace/price-index/:commodity_type
func (h *PriceIndexHandler) GetPriceIndex(c *gin.Context) {
	commodityType := c.Param("commodity_type")
	if !isValidIndexCommodity(commodityType) {
		utils.Fail(c, http.StatusBadRequest, "commodity_type must be one of coal, biomass, coke, carbon_credit", nil)
		return
	}

	index, err := h.service.GetLiveIndex(models.CommodityType(commodityType))
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute price index", err)
		return
	}

	utils.Success(c, http.StatusOK, "price index fetched", index)
}

// GetAllPriceIndexes returns the live price index for every tradeable
// commodity type in one call.
// GET /api/v1/marketplace/price-index
func (h *PriceIndexHandler) GetAllPriceIndexes(c *gin.Context) {
	indexes, err := h.service.GetAllLiveIndexes()
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute price indexes", err)
		return
	}

	utils.Success(c, http.StatusOK, "price indexes fetched", indexes)
}

// GetPriceHistory returns recorded snapshots for one commodity type, for
// charting a trend over time. Defaults to the last 90 days; source
// defaults to "transacted" (actual trade prices) since that's the more
// meaningful series for a trend chart, but can be overridden to "listing".
// GET /api/v1/marketplace/price-index/:commodity_type/history?days=90&source=transacted
func (h *PriceIndexHandler) GetPriceHistory(c *gin.Context) {
	commodityType := c.Param("commodity_type")
	if !isValidIndexCommodity(commodityType) {
		utils.Fail(c, http.StatusBadRequest, "commodity_type must be one of coal, biomass, coke, carbon_credit", nil)
		return
	}

	days := 90
	if d := c.Query("days"); d != "" {
		if parsed, err := strconv.Atoi(d); err == nil && parsed > 0 && parsed <= 365 {
			days = parsed
		}
	}

	source := c.DefaultQuery("source", "transacted")
	if source != "listing" && source != "transacted" {
		utils.Fail(c, http.StatusBadRequest, "source must be 'listing' or 'transacted'", nil)
		return
	}

	cutoff := time.Now().AddDate(0, 0, -days)

	var snapshots []models.PriceIndexSnapshot
	err := database.DB.
		Where("commodity_type = ? AND source = ? AND recorded_at >= ?", commodityType, source, cutoff).
		Order("recorded_at ASC").
		Find(&snapshots).Error
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch price history", err)
		return
	}

	utils.Success(c, http.StatusOK, "price history fetched", snapshots)
}

// RecordSnapshotAdmin manually triggers a snapshot recording, for cases
// where the background daily job (see cmd/server/main.go) hasn't fired yet
// or a backfill point is needed -- e.g. right after seeding test data in a
// fresh environment.
// POST /api/v1/marketplace/admin/price-index/snapshot
func (h *PriceIndexHandler) RecordSnapshotAdmin(c *gin.Context) {
	if err := h.service.RecordDailySnapshot(); err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to record price index snapshot", err)
		return
	}
	utils.Success(c, http.StatusOK, "price index snapshot recorded", nil)
}
