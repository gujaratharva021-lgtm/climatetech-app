package handlers

import (
	"errors"
	"net/http"
	"time"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Sentinel errors used inside AcceptBid's transaction to distinguish
// "forbidden" and "conflict" from a genuine "not found" (gorm.ErrRecordNotFound)
// without needing custom error types just for this one handler.
var (
	errRFQForbidden = errors.New("forbidden")
	errRFQConflict  = errors.New("conflict")
)

type RFQHandler struct{}

func NewRFQHandler() *RFQHandler {
	return &RFQHandler{}
}

// ---------- Buyer: create & manage RFQs ----------

type createRFQRequest struct {
	CommodityType string    `json:"commodity_type" binding:"required,oneof=coal biomass coke carbon_credit other"`
	Quantity      float64   `json:"quantity" binding:"required,gt=0"`
	Unit          string    `json:"unit" binding:"omitempty,max=20"`
	TargetPrice   float64   `json:"target_price" binding:"omitempty,gte=0"`
	Grade         string    `json:"grade" binding:"omitempty,max=500"`
	Location      string    `json:"location" binding:"omitempty,max=150"`
	Deadline      time.Time `json:"deadline" binding:"required"`
}

// CreateRFQ lets any authenticated user post a buying requirement — no
// approved-seller check here, since posting a requirement is the buyer side
// of the marketplace, open to anyone (unlike CreateListing, which requires
// an approved Seller profile).
// POST /api/v1/marketplace/rfq
func (h *RFQHandler) CreateRFQ(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var req createRFQRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	if !req.Deadline.After(time.Now()) {
		utils.Fail(c, http.StatusBadRequest, "deadline must be in the future", nil)
		return
	}

	rfq := models.RFQ{
		BuyerID:       userID,
		CommodityType: models.CommodityType(req.CommodityType),
		Quantity:      req.Quantity,
		Unit:          req.Unit,
		TargetPrice:   req.TargetPrice,
		Grade:         req.Grade,
		Location:      req.Location,
		Deadline:      req.Deadline,
		Status:        models.RFQStatusOpen,
	}
	if err := database.DB.Create(&rfq).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to create RFQ", err)
		return
	}

	utils.Success(c, http.StatusCreated, "RFQ created", rfq)
}

// BrowseRFQs lists open, not-yet-expired RFQs — this is what sellers browse
// to find requirements worth bidding on. Cancelled/awarded/expired RFQs are
// excluded since bidding on them can't lead anywhere.
// GET /api/v1/marketplace/rfq?commodity_type=&page=&limit=
func (h *RFQHandler) BrowseRFQs(c *gin.Context) {
	page, limit, offset := utils.ParsePageLimit(c, 20, 100)

	query := database.DB.Model(&models.RFQ{}).
		Where("status = ? AND deadline > ?", models.RFQStatusOpen, time.Now())
	if commodityType := c.Query("commodity_type"); commodityType != "" {
		query = query.Where("commodity_type = ?", commodityType)
	}

	var total int64
	if err := query.Count(&total).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count RFQs", err)
		return
	}

	var rfqs []models.RFQ
	if err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&rfqs).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch RFQs", err)
		return
	}

	utils.Success(c, http.StatusOK, "RFQs fetched", gin.H{
		"rfqs":  rfqs,
		"page":  page,
		"limit": limit,
		"total": total,
	})
}

// GetRFQDetail returns a single RFQ. Doesn't include its bids — those are
// sealed to the RFQ's own buyer via ListBidsForRFQ, to keep the reverse
// auction competitive (a seller browsing shouldn't see rival bids).
// GET /api/v1/marketplace/rfq/:id
func (h *RFQHandler) GetRFQDetail(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid rfq id", err)
		return
	}

	var rfq models.RFQ
	if err := database.DB.First(&rfq, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "RFQ not found", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch RFQ", err)
		return
	}

	utils.Success(c, http.StatusOK, "RFQ fetched", rfq)
}

// GetMyRFQs returns the authenticated user's own RFQs (as a buyer).
// GET /api/v1/marketplace/my-rfqs
func (h *RFQHandler) GetMyRFQs(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var rfqs []models.RFQ
	if err := database.DB.Where("buyer_id = ?", userID).Order("created_at DESC").Find(&rfqs).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch your RFQs", err)
		return
	}

	utils.Success(c, http.StatusOK, "your RFQs fetched", rfqs)
}

// CancelRFQ lets the buyer withdraw their own still-open RFQ. Scoped by
// buyer_id AND status="open" in a single UPDATE, so a mismatched id, an
// RFQ that isn't theirs, or one that's already awarded/cancelled are all
// indistinguishable "not found" to the caller — same pattern as DeleteListing.
// PUT /api/v1/marketplace/rfq/:id/cancel
func (h *RFQHandler) CancelRFQ(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid rfq id", err)
		return
	}

	result := database.DB.Model(&models.RFQ{}).
		Where("id = ? AND buyer_id = ? AND status = ?", id, userID, models.RFQStatusOpen).
		Update("status", models.RFQStatusCancelled)
	if result.Error != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to cancel RFQ", result.Error)
		return
	}
	if result.RowsAffected == 0 {
		utils.Fail(c, http.StatusNotFound, "RFQ not found, not yours, or no longer open", nil)
		return
	}

	utils.Success(c, http.StatusOK, "RFQ cancelled", nil)
}

// ---------- Seller: submit & manage bids ----------

type submitBidRequest struct {
	Price    float64 `json:"price" binding:"required,gt=0"`
	Quantity float64 `json:"quantity" binding:"required,gt=0"`
	Message  string  `json:"message" binding:"omitempty,max=1000"`
}

// SubmitBid lets a user with an approved seller profile bid on an open,
// not-yet-expired RFQ that isn't their own.
// POST /api/v1/marketplace/rfq/:id/bids
func (h *RFQHandler) SubmitBid(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	rfqID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid rfq id", err)
		return
	}

	var seller models.Seller
	if err := database.DB.Where("user_id = ? AND status = ?", userID, models.SellerStatusApproved).First(&seller).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusForbidden, "you need an approved seller profile to bid", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to check seller profile", err)
		return
	}

	var rfq models.RFQ
	if err := database.DB.First(&rfq, "id = ?", rfqID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "RFQ not found", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch RFQ", err)
		return
	}
	if rfq.Status != models.RFQStatusOpen || !rfq.Deadline.After(time.Now()) {
		utils.Fail(c, http.StatusConflict, "this RFQ is no longer accepting bids", nil)
		return
	}
	if rfq.BuyerID == userID {
		utils.Fail(c, http.StatusForbidden, "you can't bid on your own RFQ", nil)
		return
	}

	var req submitBidRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	bid := models.Bid{
		RFQID:    rfqID,
		SellerID: seller.ID,
		Price:    req.Price,
		Quantity: req.Quantity,
		Message:  req.Message,
		Status:   models.BidStatusPending,
	}
	if err := database.DB.Create(&bid).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to submit bid", err)
		return
	}

	utils.Success(c, http.StatusCreated, "bid submitted", bid)
}

// bidWithSeller decorates a bid with the minimal seller info the buyer needs
// to evaluate it, without exposing the seller's full application — same
// pattern as listingWithSeller in marketplace_handler.go.
type bidWithSeller struct {
	models.Bid
	ShopName string `json:"shop_name"`
	Verified bool   `json:"verified"`
}

// ListBidsForRFQ lets the RFQ's buyer see every bid submitted against it,
// cheapest first. Only the owning buyer can call this — bids are sealed
// from other sellers and the general public to keep the reverse auction
// competitive.
// GET /api/v1/marketplace/rfq/:id/bids
func (h *RFQHandler) ListBidsForRFQ(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	rfqID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid rfq id", err)
		return
	}

	var rfq models.RFQ
	if err := database.DB.First(&rfq, "id = ?", rfqID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "RFQ not found", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch RFQ", err)
		return
	}
	if rfq.BuyerID != userID {
		utils.Fail(c, http.StatusForbidden, "only the RFQ owner can view its bids", nil)
		return
	}

	var bids []models.Bid
	if err := database.DB.Where("rfq_id = ?", rfqID).Order("price ASC, created_at ASC").Find(&bids).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch bids", err)
		return
	}

	results, err := h.attachSellerInfoToBids(bids)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to load seller info", err)
		return
	}

	utils.Success(c, http.StatusOK, "bids fetched", results)
}

// attachSellerInfoToBids batches a single query for every seller referenced
// across the given bids, so listing N bids never costs N seller lookups —
// same pattern as MarketplaceHandler.attachSellerInfo.
func (h *RFQHandler) attachSellerInfoToBids(bids []models.Bid) ([]bidWithSeller, error) {
	results := make([]bidWithSeller, 0, len(bids))
	if len(bids) == 0 {
		return results, nil
	}

	sellerIDSet := make(map[uuid.UUID]struct{}, len(bids))
	for _, b := range bids {
		sellerIDSet[b.SellerID] = struct{}{}
	}
	sellerIDs := make([]uuid.UUID, 0, len(sellerIDSet))
	for id := range sellerIDSet {
		sellerIDs = append(sellerIDs, id)
	}

	var sellers []models.Seller
	if err := database.DB.Where("id IN ?", sellerIDs).Find(&sellers).Error; err != nil {
		return nil, err
	}
	sellerByID := make(map[uuid.UUID]models.Seller, len(sellers))
	for _, s := range sellers {
		sellerByID[s.ID] = s
	}

	for _, b := range bids {
		seller := sellerByID[b.SellerID]
		results = append(results, bidWithSeller{
			Bid:      b,
			ShopName: seller.ShopName,
			Verified: seller.Status == models.SellerStatusApproved,
		})
	}
	return results, nil
}

// GetMyBids returns the authenticated user's own bids (as a seller), via
// their seller profile.
// GET /api/v1/marketplace/my-bids
func (h *RFQHandler) GetMyBids(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var seller models.Seller
	if err := database.DB.Where("user_id = ?", userID).First(&seller).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Success(c, http.StatusOK, "no bids", []models.Bid{})
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to load seller profile", err)
		return
	}

	var bids []models.Bid
	if err := database.DB.Where("seller_id = ?", seller.ID).Order("created_at DESC").Find(&bids).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch your bids", err)
		return
	}

	utils.Success(c, http.StatusOK, "your bids fetched", bids)
}

// AcceptBid awards the RFQ to one bid: marks it accepted, rejects every
// other still-pending bid on the same RFQ, and moves the RFQ to awarded —
// all inside one transaction, so a crash mid-way can't leave two bids
// accepted or an RFQ stuck open with an already-accepted bid.
// PUT /api/v1/marketplace/rfq/:id/bids/:bid_id/accept
func (h *RFQHandler) AcceptBid(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	rfqID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid rfq id", err)
		return
	}
	bidID, err := uuid.Parse(c.Param("bid_id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid bid id", err)
		return
	}

	txErr := database.DB.Transaction(func(tx *gorm.DB) error {
		var rfq models.RFQ
		if err := tx.First(&rfq, "id = ?", rfqID).Error; err != nil {
			return err
		}
		if rfq.BuyerID != userID {
			return errRFQForbidden
		}
		if rfq.Status != models.RFQStatusOpen {
			return errRFQConflict
		}

		var bid models.Bid
		if err := tx.First(&bid, "id = ? AND rfq_id = ?", bidID, rfqID).Error; err != nil {
			return err
		}
		if bid.Status != models.BidStatusPending {
			return errRFQConflict
		}

		if err := tx.Model(&bid).Update("status", models.BidStatusAccepted).Error; err != nil {
			return err
		}
		if err := tx.Model(&models.Bid{}).
			Where("rfq_id = ? AND id != ? AND status = ?", rfqID, bidID, models.BidStatusPending).
			Update("status", models.BidStatusRejected).Error; err != nil {
			return err
		}
		if err := tx.Model(&rfq).Updates(map[string]interface{}{
			"status":         models.RFQStatusAwarded,
			"awarded_bid_id": bid.ID,
		}).Error; err != nil {
			return err
		}
		return nil
	})

	if txErr != nil {
		switch {
		case errors.Is(txErr, gorm.ErrRecordNotFound):
			utils.Fail(c, http.StatusNotFound, "RFQ or bid not found", txErr)
		case errors.Is(txErr, errRFQForbidden):
			utils.Fail(c, http.StatusForbidden, "only the RFQ owner can accept a bid", nil)
		case errors.Is(txErr, errRFQConflict):
			utils.Fail(c, http.StatusConflict, "RFQ is no longer open or bid already decided", nil)
		default:
			utils.Fail(c, http.StatusInternalServerError, "failed to accept bid", txErr)
		}
		return
	}

	utils.Success(c, http.StatusOK, "bid accepted, RFQ awarded", nil)
}

// ---------- Admin visibility ----------

// ListAllRFQsAdmin returns every RFQ regardless of status, for admin
// oversight — mirrors ListAllListingsAdmin.
// GET /api/v1/marketplace/admin/rfqs
func (h *RFQHandler) ListAllRFQsAdmin(c *gin.Context) {
	page, limit, offset := utils.ParsePageLimit(c, 20, 100)

	var total int64
	if err := database.DB.Model(&models.RFQ{}).Count(&total).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count RFQs", err)
		return
	}

	var rfqs []models.RFQ
	if err := database.DB.Order("created_at DESC").Limit(limit).Offset(offset).Find(&rfqs).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch RFQs", err)
		return
	}

	utils.Success(c, http.StatusOK, "RFQs fetched", gin.H{
		"rfqs":  rfqs,
		"page":  page,
		"limit": limit,
		"total": total,
	})
}
