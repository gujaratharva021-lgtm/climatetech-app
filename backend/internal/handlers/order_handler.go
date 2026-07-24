package handlers

import (
	"errors"
	"net/http"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Sentinel errors used inside the transactions below to distinguish
// specific failure reasons from a genuine "not found"
// (gorm.ErrRecordNotFound), without custom error types just for this file.
var (
	errOrderForbidden       = errors.New("forbidden")
	errOrderConflict        = errors.New("conflict")
	errOrderAlreadyExists   = errors.New("order already exists")
	errOrderInsufficientQty = errors.New("insufficient quantity")
	errOrderBelowMinimum    = errors.New("below minimum order quantity")
	errOrderOwnListing      = errors.New("cannot order own listing")
)

type OrderHandler struct{}

func NewOrderHandler() *OrderHandler {
	return &OrderHandler{}
}

// ---------- Creating orders ----------

type createOrderFromRFQRequest struct {
	DeliveryAddress string `json:"delivery_address" binding:"required,max=500"`
}

// CreateOrderFromRFQ turns an awarded RFQ into a trackable order. Only the
// RFQ's own buyer can call this, only once the RFQ has actually been
// awarded (see RFQHandler.AcceptBid), and only once — a second call for the
// same RFQ is rejected rather than silently creating a duplicate order.
// POST /api/v1/marketplace/rfq/:id/order
func (h *OrderHandler) CreateOrderFromRFQ(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	rfqID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid rfq id", err)
		return
	}

	var req createOrderFromRFQRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	var order models.Order
	txErr := database.DB.Transaction(func(tx *gorm.DB) error {
		var rfq models.RFQ
		if err := tx.First(&rfq, "id = ?", rfqID).Error; err != nil {
			return err
		}
		if rfq.BuyerID != userID {
			return errOrderForbidden
		}
		if rfq.Status != models.RFQStatusAwarded || rfq.AwardedBidID == nil {
			return errOrderConflict
		}

		var existing models.Order
		err := tx.Where("rfq_id = ?", rfq.ID).First(&existing).Error
		if err == nil {
			return errOrderAlreadyExists
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}

		var bid models.Bid
		if err := tx.First(&bid, "id = ?", *rfq.AwardedBidID).Error; err != nil {
			return err
		}

		order = models.Order{
			BuyerID:         userID,
			SellerID:        bid.SellerID,
			Source:          models.OrderSourceRFQ,
			RFQID:           &rfq.ID,
			BidID:           &bid.ID,
			CommodityType:   rfq.CommodityType,
			Quantity:        bid.Quantity,
			Unit:            rfq.Unit,
			PricePerUnit:    bid.Price,
			DeliveryAddress: req.DeliveryAddress,
			Status:          models.OrderStatusPlaced,
		}
		return tx.Create(&order).Error
	})

	if txErr != nil {
		switch {
		case errors.Is(txErr, gorm.ErrRecordNotFound):
			utils.Fail(c, http.StatusNotFound, "RFQ or awarded bid not found", txErr)
		case errors.Is(txErr, errOrderForbidden):
			utils.Fail(c, http.StatusForbidden, "only the RFQ owner can create an order from it", nil)
		case errors.Is(txErr, errOrderConflict):
			utils.Fail(c, http.StatusConflict, "RFQ must be awarded before an order can be created", nil)
		case errors.Is(txErr, errOrderAlreadyExists):
			utils.Fail(c, http.StatusConflict, "an order already exists for this RFQ", nil)
		default:
			utils.Fail(c, http.StatusInternalServerError, "failed to create order", txErr)
		}
		return
	}

	utils.Success(c, http.StatusCreated, "order placed", order)
}

type createOrderFromListingRequest struct {
	Quantity        float64 `json:"quantity" binding:"required,gt=0"`
	DeliveryAddress string  `json:"delivery_address" binding:"required,max=500"`
}

// CreateOrderFromListing places a direct order against an active Listing.
// Reserves stock atomically (decrements Listing.Quantity, deactivating the
// listing if that reaches zero) in the same transaction as the order
// insert, so two buyers racing on the last few units can't both succeed.
// POST /api/v1/marketplace/listings/:id/order
func (h *OrderHandler) CreateOrderFromListing(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	listingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid listing id", err)
		return
	}

	var req createOrderFromListingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	var order models.Order
	txErr := database.DB.Transaction(func(tx *gorm.DB) error {
		var listing models.Listing
		if err := tx.Where("is_active = ?", true).First(&listing, "id = ?", listingID).Error; err != nil {
			return err
		}
		if req.Quantity > listing.Quantity {
			return errOrderInsufficientQty
		}
		if listing.MinOrderQty > 0 && req.Quantity < listing.MinOrderQty {
			return errOrderBelowMinimum
		}

		var seller models.Seller
		if err := tx.First(&seller, "id = ?", listing.SellerID).Error; err != nil {
			return err
		}
		if seller.UserID == userID {
			return errOrderOwnListing
		}

		remaining := listing.Quantity - req.Quantity
		listingUpdates := map[string]interface{}{"quantity": remaining}
		if remaining <= 0 {
			listingUpdates["is_active"] = false
		}
		if err := tx.Model(&listing).Updates(listingUpdates).Error; err != nil {
			return err
		}

		order = models.Order{
			BuyerID:         userID,
			SellerID:        listing.SellerID,
			Source:          models.OrderSourceListing,
			ListingID:       &listing.ID,
			CommodityType:   listing.CommodityType,
			Quantity:        req.Quantity,
			Unit:            listing.Unit,
			PricePerUnit:    listing.Price,
			DeliveryAddress: req.DeliveryAddress,
			Status:          models.OrderStatusPlaced,
		}
		return tx.Create(&order).Error
	})

	if txErr != nil {
		switch {
		case errors.Is(txErr, gorm.ErrRecordNotFound):
			utils.Fail(c, http.StatusNotFound, "listing not found", txErr)
		case errors.Is(txErr, errOrderInsufficientQty):
			utils.Fail(c, http.StatusConflict, "not enough quantity available", nil)
		case errors.Is(txErr, errOrderBelowMinimum):
			utils.Fail(c, http.StatusBadRequest, "quantity is below the listing's minimum order quantity", nil)
		case errors.Is(txErr, errOrderOwnListing):
			utils.Fail(c, http.StatusForbidden, "you can't order your own listing", nil)
		default:
			utils.Fail(c, http.StatusInternalServerError, "failed to create order", txErr)
		}
		return
	}

	utils.Success(c, http.StatusCreated, "order placed", order)
}

// ---------- Viewing orders ----------

// GetOrderDetail returns a single order to either party involved — the
// buyer, or the seller it was placed against (verified via the caller's own
// Seller profile, not a client-supplied seller id).
// GET /api/v1/marketplace/orders/:id
func (h *OrderHandler) GetOrderDetail(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid order id", err)
		return
	}

	var order models.Order
	if err := database.DB.First(&order, "id = ?", id).Error; err != nil {
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

	utils.Success(c, http.StatusOK, "order fetched", order)
}

// GetMyOrdersAsBuyer returns the authenticated user's own orders as a buyer.
// GET /api/v1/marketplace/my-orders
func (h *OrderHandler) GetMyOrdersAsBuyer(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var orders []models.Order
	if err := database.DB.Where("buyer_id = ?", userID).Order("created_at DESC").Find(&orders).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch your orders", err)
		return
	}

	utils.Success(c, http.StatusOK, "your orders fetched", orders)
}

// GetMySellerOrders returns the authenticated user's incoming orders as a
// seller, via their seller profile.
// GET /api/v1/marketplace/seller/orders
func (h *OrderHandler) GetMySellerOrders(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var seller models.Seller
	if err := database.DB.Where("user_id = ?", userID).First(&seller).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Success(c, http.StatusOK, "no orders", []models.Order{})
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to load seller profile", err)
		return
	}

	var orders []models.Order
	if err := database.DB.Where("seller_id = ?", seller.ID).Order("created_at DESC").Find(&orders).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch your orders", err)
		return
	}

	utils.Success(c, http.StatusOK, "your orders fetched", orders)
}

// ---------- Fulfillment status transitions ----------

// updateOrderStatusAsSeller is the shared implementation behind ConfirmOrder
// and ShipOrder: both are "the seller moves their own order from one exact
// status to the next", scoped by the caller's own Seller profile so an id
// mismatch is indistinguishable from "not found" — same pattern as
// MarketplaceHandler.updateSellerStatus.
func (h *OrderHandler) updateOrderStatusAsSeller(c *gin.Context, from, to models.OrderStatus) {
	userID := c.MustGet("user_id").(uuid.UUID)

	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid order id", err)
		return
	}

	var seller models.Seller
	if err := database.DB.Where("user_id = ?", userID).First(&seller).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusForbidden, "you don't have a seller profile", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to check seller profile", err)
		return
	}

	result := database.DB.Model(&models.Order{}).
		Where("id = ? AND seller_id = ? AND status = ?", id, seller.ID, from).
		Update("status", to)
	if result.Error != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to update order", result.Error)
		return
	}
	if result.RowsAffected == 0 {
		utils.Fail(c, http.StatusNotFound, "order not found, not yours, or not in the expected status", nil)
		return
	}

	utils.Success(c, http.StatusOK, "order status updated", nil)
}

// ConfirmOrder: seller confirms a newly placed order.
// PUT /api/v1/marketplace/orders/:id/confirm
func (h *OrderHandler) ConfirmOrder(c *gin.Context) {
	h.updateOrderStatusAsSeller(c, models.OrderStatusPlaced, models.OrderStatusConfirmed)
}

// ShipOrder: seller marks a confirmed order as shipped.
// PUT /api/v1/marketplace/orders/:id/ship
func (h *OrderHandler) ShipOrder(c *gin.Context) {
	h.updateOrderStatusAsSeller(c, models.OrderStatusConfirmed, models.OrderStatusShipped)
}

// DeliverOrder: buyer confirms a shipped order has arrived. Buyer-side
// (not seller-side) confirmation, since "did it actually arrive" is the
// buyer's call — and this is the signal Phase 4's escrow release will
// eventually hook into.
// PUT /api/v1/marketplace/orders/:id/deliver
func (h *OrderHandler) DeliverOrder(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid order id", err)
		return
	}

	result := database.DB.Model(&models.Order{}).
		Where("id = ? AND buyer_id = ? AND status = ?", id, userID, models.OrderStatusShipped).
		Update("status", models.OrderStatusDelivered)
	if result.Error != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to update order", result.Error)
		return
	}
	if result.RowsAffected == 0 {
		utils.Fail(c, http.StatusNotFound, "order not found, not yours, or not shipped yet", nil)
		return
	}

	utils.Success(c, http.StatusOK, "order marked delivered", nil)
}

// CancelOrder: buyer cancels their own order, but only while it's still
// "placed" — once a seller has confirmed it, cancelling needs a real
// conversation rather than a one-click API call. If the order came from a
// Listing, the reserved quantity is added back (and the listing
// reactivated if it had been deactivated at zero stock) in the same
// transaction as the cancellation.
// PUT /api/v1/marketplace/orders/:id/cancel
func (h *OrderHandler) CancelOrder(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid order id", err)
		return
	}

	txErr := database.DB.Transaction(func(tx *gorm.DB) error {
		var order models.Order
		if err := tx.First(&order, "id = ? AND buyer_id = ?", id, userID).Error; err != nil {
			return err
		}
		if order.Status != models.OrderStatusPlaced {
			return errOrderConflict
		}

		if err := tx.Model(&order).Update("status", models.OrderStatusCancelled).Error; err != nil {
			return err
		}

		if order.Source == models.OrderSourceListing && order.ListingID != nil {
			if err := tx.Model(&models.Listing{}).Where("id = ?", *order.ListingID).
				Updates(map[string]interface{}{
					"quantity":  gorm.Expr("quantity + ?", order.Quantity),
					"is_active": true,
				}).Error; err != nil {
				return err
			}
		}
		return nil
	})

	if txErr != nil {
		switch {
		case errors.Is(txErr, gorm.ErrRecordNotFound):
			utils.Fail(c, http.StatusNotFound, "order not found or not yours", txErr)
		case errors.Is(txErr, errOrderConflict):
			utils.Fail(c, http.StatusConflict, "order can only be cancelled while still placed", nil)
		default:
			utils.Fail(c, http.StatusInternalServerError, "failed to cancel order", txErr)
		}
		return
	}

	utils.Success(c, http.StatusOK, "order cancelled", nil)
}

// ---------- Admin visibility ----------

// ListAllOrdersAdmin returns every order regardless of status, for admin
// oversight — mirrors ListAllListingsAdmin / ListAllRFQsAdmin.
// GET /api/v1/marketplace/admin/orders
func (h *OrderHandler) ListAllOrdersAdmin(c *gin.Context) {
	page, limit, offset := utils.ParsePageLimit(c, 20, 100)

	var total int64
	if err := database.DB.Model(&models.Order{}).Count(&total).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count orders", err)
		return
	}

	var orders []models.Order
	if err := database.DB.Order("created_at DESC").Limit(limit).Offset(offset).Find(&orders).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch orders", err)
		return
	}

	utils.Success(c, http.StatusOK, "orders fetched", gin.H{
		"orders": orders,
		"page":   page,
		"limit":  limit,
		"total":  total,
	})
}
