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

var errShipmentAlreadyExists = errors.New("shipment already exists")

type ShipmentHandler struct{}

func NewShipmentHandler() *ShipmentHandler {
	return &ShipmentHandler{}
}

// ---------- Seller: create & update shipment ----------

type createShipmentRequest struct {
	CarrierName           string     `json:"carrier_name" binding:"required,max=150"`
	VehicleNumber         string     `json:"vehicle_number" binding:"omitempty,max=50"`
	DriverName            string     `json:"driver_name" binding:"omitempty,max=150"`
	DriverPhone           string     `json:"driver_phone" binding:"omitempty,max=20"`
	TrackingNumber        string     `json:"tracking_number" binding:"omitempty,max=100"`
	EstimatedDeliveryDate *time.Time `json:"estimated_delivery_date"`
}

// CreateShipment lets the order's seller attach logistics details (carrier,
// vehicle, driver, tracking number) to a confirmed order. If the order is
// still "confirmed", this also moves it to "shipped" in the same
// transaction -- the detailed-dispatch counterpart to OrderHandler.ShipOrder's
// quick one-click version; whichever happens first wins, since both require
// the same "confirmed" starting state.
// POST /api/v1/marketplace/orders/:id/shipment
func (h *ShipmentHandler) CreateShipment(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	orderID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid order id", err)
		return
	}

	var req createShipmentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
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

	var shipment models.Shipment
	txErr := database.DB.Transaction(func(tx *gorm.DB) error {
		var order models.Order
		if err := tx.First(&order, "id = ? AND seller_id = ?", orderID, seller.ID).Error; err != nil {
			return err
		}
		if order.Status != models.OrderStatusConfirmed && order.Status != models.OrderStatusShipped {
			return errOrderConflict
		}

		var existing models.Shipment
		err := tx.Where("order_id = ?", orderID).First(&existing).Error
		if err == nil {
			return errShipmentAlreadyExists
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}

		shipment = models.Shipment{
			OrderID:               orderID,
			CarrierName:           req.CarrierName,
			VehicleNumber:         req.VehicleNumber,
			DriverName:            req.DriverName,
			DriverPhone:           req.DriverPhone,
			TrackingNumber:        req.TrackingNumber,
			EstimatedDeliveryDate: req.EstimatedDeliveryDate,
			Status:                models.ShipmentStatusPending,
		}
		if err := tx.Create(&shipment).Error; err != nil {
			return err
		}

		if order.Status == models.OrderStatusConfirmed {
			if err := tx.Model(&order).Update("status", models.OrderStatusShipped).Error; err != nil {
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
			utils.Fail(c, http.StatusConflict, "order must be confirmed (or already shipped) to attach a shipment", nil)
		case errors.Is(txErr, errShipmentAlreadyExists):
			utils.Fail(c, http.StatusConflict, "a shipment already exists for this order", nil)
		default:
			utils.Fail(c, http.StatusInternalServerError, "failed to create shipment", txErr)
		}
		return
	}

	utils.Success(c, http.StatusCreated, "shipment created", shipment)
}

type updateShipmentStatusRequest struct {
	Status             string `json:"status" binding:"required,oneof=dispatched in_transit delivered failed"`
	CurrentLocation    string `json:"current_location" binding:"omitempty,max=200"`
	ProofOfDeliveryURL string `json:"proof_of_delivery_url" binding:"omitempty,max=500,url"`
}

// UpdateShipmentStatus lets the shipment's own seller update tracking
// status and location. This only updates the Shipment -- it does NOT move
// Order.Status to "delivered" even when Status="delivered" is set here,
// since confirming actual receipt is the buyer's call (OrderHandler.DeliverOrder),
// not something a status update from the shipping side should be able to
// force on its own.
// PUT /api/v1/marketplace/shipments/:id/status
func (h *ShipmentHandler) UpdateShipmentStatus(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	shipmentID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid shipment id", err)
		return
	}

	var req updateShipmentStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
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

	var shipment models.Shipment
	if err := database.DB.First(&shipment, "id = ?", shipmentID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "shipment not found", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch shipment", err)
		return
	}

	var order models.Order
	if err := database.DB.First(&order, "id = ? AND seller_id = ?", shipment.OrderID, seller.ID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusForbidden, "you don't have access to this shipment", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to verify shipment ownership", err)
		return
	}

	updates := map[string]interface{}{"status": req.Status}
	if req.CurrentLocation != "" {
		updates["current_location"] = req.CurrentLocation
	}
	if req.ProofOfDeliveryURL != "" {
		updates["proof_of_delivery_url"] = req.ProofOfDeliveryURL
	}
	if err := database.DB.Model(&shipment).Updates(updates).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to update shipment", err)
		return
	}

	utils.Success(c, http.StatusOK, "shipment status updated", nil)
}

// ---------- Viewing ----------

// GetShipmentByOrder returns the shipment for an order, to either the
// buyer or the order's seller -- same access pattern as
// OrderHandler.GetOrderDetail / PaymentHandler.GetPaymentStatus.
// GET /api/v1/marketplace/orders/:id/shipment
func (h *ShipmentHandler) GetShipmentByOrder(c *gin.Context) {
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

	var shipment models.Shipment
	if err := database.DB.Where("order_id = ?", orderID).First(&shipment).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Success(c, http.StatusOK, "no shipment yet", nil)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch shipment", err)
		return
	}

	utils.Success(c, http.StatusOK, "shipment fetched", shipment)
}

// ---------- Admin visibility ----------

// ListAllShipmentsAdmin returns every shipment regardless of status, for
// admin oversight -- mirrors the other ListAll*Admin handlers.
// GET /api/v1/marketplace/admin/shipments
func (h *ShipmentHandler) ListAllShipmentsAdmin(c *gin.Context) {
	page, limit, offset := utils.ParsePageLimit(c, 20, 100)

	var total int64
	if err := database.DB.Model(&models.Shipment{}).Count(&total).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count shipments", err)
		return
	}

	var shipments []models.Shipment
	if err := database.DB.Order("created_at DESC").Limit(limit).Offset(offset).Find(&shipments).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch shipments", err)
		return
	}

	utils.Success(c, http.StatusOK, "shipments fetched", gin.H{
		"shipments": shipments,
		"page":      page,
		"limit":     limit,
		"total":     total,
	})
}
