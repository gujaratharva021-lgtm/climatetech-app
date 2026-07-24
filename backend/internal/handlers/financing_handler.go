package handlers

import (
	"errors"
	"fmt"
	"net/http"
	"time"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

var (
	errFinancingForbidden      = errors.New("forbidden")
	errFinancingConflict       = errors.New("conflict")
	errFinancingExceedsInvoice = errors.New("exceeds invoice value")
	errFinancingAlreadyExists  = errors.New("financing already exists for this order")
)

// allowedFinancingTransitions is the explicit state machine admins can
// move a FinancingRequest through -- see UpdateFinancingStatusAdmin. Any
// (from, to) pair not listed here is rejected, so e.g. "pending" can never
// jump straight to "repaid" by mistake.
var allowedFinancingTransitions = map[models.FinancingStatus][]models.FinancingStatus{
	models.FinancingStatusPending:     {models.FinancingStatusUnderReview, models.FinancingStatusRejected},
	models.FinancingStatusUnderReview: {models.FinancingStatusApproved, models.FinancingStatusRejected},
	models.FinancingStatusApproved:    {models.FinancingStatusDisbursed, models.FinancingStatusRejected},
	models.FinancingStatusDisbursed:   {models.FinancingStatusRepaid, models.FinancingStatusDefaulted},
}

func isAllowedFinancingTransition(from, to models.FinancingStatus) bool {
	for _, allowed := range allowedFinancingTransitions[from] {
		if allowed == to {
			return true
		}
	}
	return false
}

// financingActiveStatuses are the statuses that count as "an invoice is
// currently being financed" -- used to block a second simultaneous
// financing request against the same order. Financing the same invoice
// twice at once (with two different lenders, say) is a real fraud pattern
// in invoice financing, not just a data-hygiene nicety.
var financingActiveStatuses = []models.FinancingStatus{
	models.FinancingStatusPending,
	models.FinancingStatusUnderReview,
	models.FinancingStatusApproved,
	models.FinancingStatusDisbursed,
}

type FinancingHandler struct{}

func NewFinancingHandler() *FinancingHandler {
	return &FinancingHandler{}
}

// ---------- Requesting financing ----------

type createFinancingRequestRequest struct {
	RequestedAmount float64 `json:"requested_amount" binding:"required,gt=0"`
	Purpose         string  `json:"purpose" binding:"omitempty,max=500"`
}

// CreateFinancingRequest lets either party on an order (buyer seeking
// working capital, or seller seeking early payment / invoice discounting)
// request financing against it. Blocked if the order is cancelled, if the
// requested amount exceeds the invoice value, or if the order already has
// an active (non-terminal) financing request -- see financingActiveStatuses.
// POST /api/v1/marketplace/orders/:id/financing
func (h *FinancingHandler) CreateFinancingRequest(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	orderID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid order id", err)
		return
	}

	var req createFinancingRequestRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	var financing models.FinancingRequest
	txErr := database.DB.Transaction(func(tx *gorm.DB) error {
		var order models.Order
		if err := tx.First(&order, "id = ?", orderID).Error; err != nil {
			return err
		}
		if order.Status == models.OrderStatusCancelled {
			return errFinancingConflict
		}
		if req.RequestedAmount > order.TotalAmount {
			return errFinancingExceedsInvoice
		}

		role := models.FinancingRequesterBuyer
		if order.BuyerID != userID {
			var seller models.Seller
			if err := tx.Where("id = ? AND user_id = ?", order.SellerID, userID).First(&seller).Error; err != nil {
				return errFinancingForbidden
			}
			role = models.FinancingRequesterSeller
		}

		var existing models.FinancingRequest
		err := tx.Where("order_id = ? AND status IN ?", orderID, financingActiveStatuses).First(&existing).Error
		if err == nil {
			return errFinancingAlreadyExists
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}

		financing = models.FinancingRequest{
			OrderID:         orderID,
			RequesterID:     userID,
			RequesterRole:   role,
			RequestedAmount: req.RequestedAmount,
			Purpose:         req.Purpose,
			Status:          models.FinancingStatusPending,
		}
		return tx.Create(&financing).Error
	})

	if txErr != nil {
		switch {
		case errors.Is(txErr, gorm.ErrRecordNotFound):
			utils.Fail(c, http.StatusNotFound, "order not found", txErr)
		case errors.Is(txErr, errFinancingForbidden):
			utils.Fail(c, http.StatusForbidden, "you don't have access to this order", nil)
		case errors.Is(txErr, errFinancingConflict):
			utils.Fail(c, http.StatusConflict, "can't request financing on a cancelled order", nil)
		case errors.Is(txErr, errFinancingExceedsInvoice):
			utils.Fail(c, http.StatusBadRequest, "requested amount exceeds the order's total value", nil)
		case errors.Is(txErr, errFinancingAlreadyExists):
			utils.Fail(c, http.StatusConflict, "this order already has an active financing request", nil)
		default:
			utils.Fail(c, http.StatusInternalServerError, "failed to create financing request", txErr)
		}
		return
	}

	utils.Success(c, http.StatusCreated, "financing request submitted", financing)
}

// ---------- Viewing ----------

// GetFinancingRequest returns a single financing request to the user who
// requested it.
// GET /api/v1/marketplace/financing/:id
func (h *FinancingHandler) GetFinancingRequest(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid financing request id", err)
		return
	}

	var financing models.FinancingRequest
	if err := database.DB.First(&financing, "id = ? AND requester_id = ?", id, userID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "financing request not found or not yours", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch financing request", err)
		return
	}

	utils.Success(c, http.StatusOK, "financing request fetched", financing)
}

// GetMyFinancingRequests returns every financing request the authenticated
// user has made, on either side (as buyer or seller).
// GET /api/v1/marketplace/my-financing
func (h *FinancingHandler) GetMyFinancingRequests(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var requests []models.FinancingRequest
	if err := database.DB.Where("requester_id = ?", userID).Order("created_at DESC").Find(&requests).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch your financing requests", err)
		return
	}

	utils.Success(c, http.StatusOK, "your financing requests fetched", requests)
}

// GetFinancingForOrder returns every financing request tied to an order,
// to either the buyer or the seller -- so both parties can see the
// invoice's financing state even if only one of them requested it. Same
// dual-access pattern as OrderHandler.GetOrderDetail.
// GET /api/v1/marketplace/orders/:id/financing
func (h *FinancingHandler) GetFinancingForOrder(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	orderID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid order id", err)
		return
	}

	var order models.Order
	if err := database.DB.First(&order, "id = ?", orderID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "order not found", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch order", err)
		return
	}
	if order.BuyerID != userID {
		var seller models.Seller
		if err := database.DB.Where("id = ? AND user_id = ?", order.SellerID, userID).First(&seller).Error; err != nil {
			utils.Fail(c, http.StatusForbidden, "you don't have access to this order", nil)
			return
		}
	}

	var requests []models.FinancingRequest
	if err := database.DB.Where("order_id = ?", orderID).Order("created_at DESC").Find(&requests).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch financing requests", err)
		return
	}

	utils.Success(c, http.StatusOK, "financing requests fetched", requests)
}

// ---------- Admin review ----------

// ListAllFinancingAdmin returns every financing request, optionally
// filtered by status, for the admin review queue.
// GET /api/v1/marketplace/admin/financing?status=
func (h *FinancingHandler) ListAllFinancingAdmin(c *gin.Context) {
	page, limit, offset := utils.ParsePageLimit(c, 20, 100)

	query := database.DB.Model(&models.FinancingRequest{})
	if status := c.Query("status"); status != "" {
		query = query.Where("status = ?", status)
	}

	var total int64
	if err := query.Count(&total).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count financing requests", err)
		return
	}

	var requests []models.FinancingRequest
	if err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&requests).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch financing requests", err)
		return
	}

	utils.Success(c, http.StatusOK, "financing requests fetched", gin.H{
		"requests": requests,
		"page":     page,
		"limit":    limit,
		"total":    total,
	})
}

type updateFinancingStatusRequest struct {
	Status         string  `json:"status" binding:"required,oneof=under_review approved rejected disbursed repaid defaulted"`
	LenderName     string  `json:"lender_name" binding:"omitempty,max=150"`
	ApprovedAmount float64 `json:"approved_amount" binding:"omitempty,gt=0"`
	InterestRate   float64 `json:"interest_rate" binding:"omitempty,gte=0"`
	AdminNotes     string  `json:"admin_notes" binding:"omitempty,max=1000"`
}

// UpdateFinancingStatusAdmin moves a financing request through the state
// machine (see allowedFinancingTransitions) -- an admin standing in for a
// human ops team's manual review, or a future real lender-API integration.
// Sets DisbursedAt/RepaidAt automatically when transitioning into those
// states, so those timestamps can't drift from the actual status change.
// PUT /api/v1/marketplace/admin/financing/:id
func (h *FinancingHandler) UpdateFinancingStatusAdmin(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid financing request id", err)
		return
	}

	var req updateFinancingStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}
	newStatus := models.FinancingStatus(req.Status)

	var financing models.FinancingRequest
	if err := database.DB.First(&financing, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "financing request not found", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch financing request", err)
		return
	}

	if !isAllowedFinancingTransition(financing.Status, newStatus) {
		utils.Fail(c, http.StatusConflict, fmt.Sprintf("cannot move a financing request from %s to %s", financing.Status, newStatus), nil)
		return
	}

	updates := map[string]interface{}{"status": newStatus}
	if req.LenderName != "" {
		updates["lender_name"] = req.LenderName
	}
	if req.ApprovedAmount > 0 {
		updates["approved_amount"] = req.ApprovedAmount
	}
	if req.InterestRate > 0 {
		updates["interest_rate"] = req.InterestRate
	}
	if req.AdminNotes != "" {
		updates["admin_notes"] = req.AdminNotes
	}
	now := time.Now()
	if newStatus == models.FinancingStatusDisbursed {
		updates["disbursed_at"] = &now
	}
	if newStatus == models.FinancingStatusRepaid {
		updates["repaid_at"] = &now
	}

	if err := database.DB.Model(&financing).Updates(updates).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to update financing request", err)
		return
	}

	utils.Success(c, http.StatusOK, "financing request updated", nil)
}
