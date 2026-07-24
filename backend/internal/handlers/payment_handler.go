package handlers

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/services"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type PaymentHandler struct {
	razorpay      *services.RazorpayService
	webhookSecret string
	publicKeyID   string
}

func NewPaymentHandler(razorpay *services.RazorpayService, webhookSecret, publicKeyID string) *PaymentHandler {
	return &PaymentHandler{razorpay: razorpay, webhookSecret: webhookSecret, publicKeyID: publicKeyID}
}

// ---------- Buyer: checkout ----------

// CreatePaymentOrder starts checkout for an order: creates a Razorpay order
// for the order's total and returns what the frontend needs to open
// Razorpay Checkout (razorpay_order_id, amount, currency, and the public
// key id -- never the secret). If a not-yet-completed attempt already
// exists for this order, that same Razorpay order is reused instead of
// creating a duplicate -- the common case being the buyer closed the
// checkout widget and is retrying.
// POST /api/v1/marketplace/orders/:id/payment/create
func (h *PaymentHandler) CreatePaymentOrder(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	orderID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid order id", err)
		return
	}

	var order models.Order
	if err := database.DB.First(&order, "id = ? AND buyer_id = ?", orderID, userID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "order not found or not yours", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch order", err)
		return
	}

	var existing models.Payment
	err = database.DB.Where("order_id = ?", orderID).Order("created_at DESC").First(&existing).Error
	switch {
	case err == nil && existing.Status == models.PaymentStatusPaid:
		utils.Fail(c, http.StatusConflict, "this order has already been paid", nil)
		return
	case err == nil && existing.Status == models.PaymentStatusCreated:
		utils.Success(c, http.StatusOK, "existing payment resumed", gin.H{
			"razorpay_order_id": existing.RazorpayOrderID,
			"amount":            existing.Amount,
			"currency":          existing.Currency,
			"key_id":            h.publicKeyID,
		})
		return
	case err != nil && !errors.Is(err, gorm.ErrRecordNotFound):
		utils.Fail(c, http.StatusInternalServerError, "failed to check existing payment", err)
		return
	}

	razorpayOrderID, err := h.razorpay.CreateOrder(order.TotalAmount, order.ID.String())
	if err != nil {
		utils.Fail(c, http.StatusBadGateway, "failed to create razorpay order", err)
		return
	}

	payment := models.Payment{
		OrderID:         order.ID,
		RazorpayOrderID: razorpayOrderID,
		Amount:          order.TotalAmount,
		Currency:        "INR",
		Status:          models.PaymentStatusCreated,
	}
	if err := database.DB.Create(&payment).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to save payment record", err)
		return
	}

	utils.Success(c, http.StatusCreated, "payment order created", gin.H{
		"razorpay_order_id": payment.RazorpayOrderID,
		"amount":            payment.Amount,
		"currency":          payment.Currency,
		"key_id":            h.publicKeyID,
	})
}

type verifyPaymentRequest struct {
	RazorpayOrderID   string `json:"razorpay_order_id" binding:"required"`
	RazorpayPaymentID string `json:"razorpay_payment_id" binding:"required"`
	RazorpaySignature string `json:"razorpay_signature" binding:"required"`
}

// VerifyPayment is called by the frontend right after Razorpay Checkout
// reports success. The order/payment ids Checkout hands back are NOT proof
// of payment by themselves -- the signature is what's actually verified
// here, using Razorpay's documented HMAC scheme, before anything is marked
// paid. RazorpayWebhook (below) is the second, server-authoritative path
// that reaches the same state even if the buyer closes the tab before this
// endpoint gets called -- whichever fires first wins, the other is a no-op.
// POST /api/v1/marketplace/orders/:id/payment/verify
func (h *PaymentHandler) VerifyPayment(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	orderID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid order id", err)
		return
	}

	var req verifyPaymentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	var order models.Order
	if err := database.DB.First(&order, "id = ? AND buyer_id = ?", orderID, userID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "order not found or not yours", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch order", err)
		return
	}

	if !h.razorpay.VerifyPaymentSignature(req.RazorpayOrderID, req.RazorpayPaymentID, req.RazorpaySignature) {
		utils.Fail(c, http.StatusBadRequest, "payment signature verification failed", nil)
		return
	}

	result := database.DB.Model(&models.Payment{}).
		Where("order_id = ? AND razorpay_order_id = ? AND status = ?", orderID, req.RazorpayOrderID, models.PaymentStatusCreated).
		Updates(map[string]interface{}{
			"status":              models.PaymentStatusPaid,
			"razorpay_payment_id": req.RazorpayPaymentID,
			"razorpay_signature":  req.RazorpaySignature,
		})
	if result.Error != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to update payment", result.Error)
		return
	}
	if result.RowsAffected == 0 {
		// Not necessarily an error -- RazorpayWebhook may have already
		// marked this paid first. That's a normal race, not a failure.
		utils.Success(c, http.StatusOK, "payment already recorded", nil)
		return
	}

	utils.Success(c, http.StatusOK, "payment verified", nil)
}

// ---------- Razorpay webhook (public, no auth) ----------

type razorpayWebhookPayload struct {
	Event   string `json:"event"`
	Payload struct {
		Payment struct {
			Entity struct {
				ID      string `json:"id"`
				OrderID string `json:"order_id"`
				Status  string `json:"status"`
			} `json:"entity"`
		} `json:"payment"`
	} `json:"payload"`
}

// RazorpayWebhook is the server-authoritative confirmation path: Razorpay
// calls this directly (not through the buyer's browser), so payment
// confirmation doesn't depend on the buyer's client staying open long
// enough to call VerifyPayment. Registered outside the normal authenticated
// API group -- Razorpay can't send a JWT -- signature verification (below)
// is what authenticates the caller instead.
// POST /webhooks/razorpay
func (h *PaymentHandler) RazorpayWebhook(c *gin.Context) {
	rawBody, err := io.ReadAll(c.Request.Body)
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "failed to read request body", err)
		return
	}

	signature := c.GetHeader("X-Razorpay-Signature")
	if !h.razorpay.VerifyWebhookSignature(rawBody, signature, h.webhookSecret) {
		utils.Fail(c, http.StatusBadRequest, "invalid webhook signature", nil)
		return
	}

	var payload razorpayWebhookPayload
	if err := json.Unmarshal(rawBody, &payload); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid webhook payload", err)
		return
	}

	// Only payment.captured moves a Payment to "paid" -- everything else
	// (payment.failed, refund events, etc.) is acknowledged with 200 so
	// Razorpay doesn't retry-storm this endpoint, but changes no state here.
	if payload.Event == "payment.captured" {
		entity := payload.Payload.Payment.Entity
		database.DB.Model(&models.Payment{}).
			Where("razorpay_order_id = ? AND status = ?", entity.OrderID, models.PaymentStatusCreated).
			Updates(map[string]interface{}{
				"status":              models.PaymentStatusPaid,
				"razorpay_payment_id": entity.ID,
			})
	}

	c.JSON(http.StatusOK, gin.H{"received": true})
}

// ---------- Viewing ----------

// GetPaymentStatus returns the latest payment for an order, to either the
// buyer or the order's seller (verified via the caller's own Seller
// profile, same pattern as OrderHandler.GetOrderDetail).
// GET /api/v1/marketplace/orders/:id/payment
func (h *PaymentHandler) GetPaymentStatus(c *gin.Context) {
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

	var payment models.Payment
	if err := database.DB.Where("order_id = ?", orderID).Order("created_at DESC").First(&payment).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Success(c, http.StatusOK, "no payment yet", nil)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch payment", err)
		return
	}

	utils.Success(c, http.StatusOK, "payment fetched", payment)
}

// ---------- Admin: escrow release & refunds ----------

// ReleaseEscrow marks a paid, delivered order's escrow as released to the
// seller.
//
// IMPORTANT LIMITATION: this only records that release happened -- it does
// NOT move money. Automatic split payouts to sellers need Razorpay Route
// (linked sub-merchant accounts with their own KYC), a significant separate
// integration; until that's built, actually paying the seller their share
// is a manual bank transfer/settlement step outside this API. This
// endpoint exists so that manual step has a clear, auditable trigger and an
// order/payment state to check against, rather than pretending automated
// payout already works.
// PUT /api/v1/marketplace/admin/orders/:id/release-escrow
func (h *PaymentHandler) ReleaseEscrow(c *gin.Context) {
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
	if order.Status != models.OrderStatusDelivered {
		utils.Fail(c, http.StatusConflict, "order must be delivered before escrow can be released", nil)
		return
	}

	result := database.DB.Model(&models.Payment{}).
		Where("order_id = ? AND status = ?", orderID, models.PaymentStatusPaid).
		Update("status", models.PaymentStatusReleased)
	if result.Error != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to release escrow", result.Error)
		return
	}
	if result.RowsAffected == 0 {
		utils.Fail(c, http.StatusConflict, "no paid payment found for this order", nil)
		return
	}

	utils.Success(c, http.StatusOK, "escrow marked released -- this records the decision only, it does not itself transfer funds (see handler doc comment)", nil)
}

// RefundPayment issues a full Razorpay refund for a paid order's payment.
// PUT /api/v1/marketplace/admin/orders/:id/refund
func (h *PaymentHandler) RefundPayment(c *gin.Context) {
	orderID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid order id", err)
		return
	}

	var payment models.Payment
	if err := database.DB.Where("order_id = ? AND status = ?", orderID, models.PaymentStatusPaid).
		Order("created_at DESC").First(&payment).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "no paid payment found for this order", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch payment", err)
		return
	}

	refundID, err := h.razorpay.CreateRefund(payment.RazorpayPaymentID)
	if err != nil {
		utils.Fail(c, http.StatusBadGateway, "failed to create razorpay refund", err)
		return
	}

	if err := database.DB.Model(&payment).Updates(map[string]interface{}{
		"status":    models.PaymentStatusRefunded,
		"refund_id": refundID,
	}).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "refund issued at razorpay but failed to update local record -- reconcile manually", err)
		return
	}

	utils.Success(c, http.StatusOK, "payment refunded", gin.H{"refund_id": refundID})
}
