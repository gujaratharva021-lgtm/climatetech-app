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

type LogisticsHandler struct{}

func NewLogisticsHandler() *LogisticsHandler {
	return &LogisticsHandler{}
}

// ---------- Vehicle Listing ----------

type CreateVehicleRequest struct {
	VehicleType  string  `json:"vehicle_type" binding:"required,oneof=truck trailer mini_van container"`
	RegNumber    string  `json:"reg_number" binding:"required,min=4,max=50"`
	CapacityKg   float64 `json:"capacity_kg" binding:"required,gt=0"`
	CapacityUnit string  `json:"capacity_unit" binding:"omitempty"`
	BaseLocation string  `json:"base_location" binding:"omitempty,max=255"`
	PricePerKm   float64 `json:"price_per_km" binding:"required,gt=0"`
}

func (h *LogisticsHandler) CreateVehicle(c *gin.Context) {
	ownerID, ok := currentUserID(c)
	if !ok {
		utils.Fail(c, http.StatusUnauthorized, "unauthenticated", nil)
		return
	}

	var req CreateVehicleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	vehicle := models.Vehicle{
		OwnerID:      ownerID,
		VehicleType:  models.VehicleType(req.VehicleType),
		RegNumber:    req.RegNumber,
		CapacityKg:   req.CapacityKg,
		CapacityUnit: req.CapacityUnit,
		BaseLocation: req.BaseLocation,
		PricePerKm:   req.PricePerKm,
	}

	if err := database.DB.Create(&vehicle).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to list vehicle", err)
		return
	}

	utils.Success(c, http.StatusCreated, "vehicle listed", vehicle)
}

func (h *LogisticsHandler) BrowseVehicles(c *gin.Context) {
	page, limit, offset := utils.ParsePageLimit(c, 20, 100)

	query := database.DB.Model(&models.Vehicle{}).Where("status = ?", models.VehicleStatusAvailable)

	if vType := c.Query("vehicle_type"); vType != "" {
		query = query.Where("vehicle_type = ?", vType)
	}
	if loc := c.Query("location"); loc != "" {
		query = query.Where("base_location ILIKE ?", "%"+loc+"%")
	}

	var total int64
	if err := query.Count(&total).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count vehicles", err)
		return
	}

	var vehicles []models.Vehicle
	if err := query.Order("created_at DESC").Offset(offset).Limit(limit).Find(&vehicles).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch vehicles", err)
		return
	}

	utils.Success(c, http.StatusOK, "vehicles fetched", gin.H{
		"page": page, "limit": limit, "total": total, "vehicles": vehicles,
	})
}

func (h *LogisticsHandler) GetVehicle(c *gin.Context) {
	vehicleID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid vehicle id", err)
		return
	}

	var vehicle models.Vehicle
	if err := database.DB.First(&vehicle, "id = ?", vehicleID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "vehicle not found", nil)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch vehicle", err)
		return
	}

	utils.Success(c, http.StatusOK, "vehicle fetched", vehicle)
}

func (h *LogisticsHandler) GetMyVehicles(c *gin.Context) {
	ownerID, ok := currentUserID(c)
	if !ok {
		utils.Fail(c, http.StatusUnauthorized, "unauthenticated", nil)
		return
	}

	var vehicles []models.Vehicle
	if err := database.DB.Where("owner_id = ?", ownerID).Order("created_at DESC").Find(&vehicles).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch your vehicles", err)
		return
	}

	utils.Success(c, http.StatusOK, "your vehicles fetched", vehicles)
}

type UpdateVehicleRequest struct {
	CapacityKg   *float64 `json:"capacity_kg" binding:"omitempty,gt=0"`
	BaseLocation *string  `json:"base_location" binding:"omitempty,max=255"`
	PricePerKm   *float64 `json:"price_per_km" binding:"omitempty,gt=0"`
	Status       *string  `json:"status" binding:"omitempty,oneof=available maintenance inactive"`
}

func (h *LogisticsHandler) UpdateVehicle(c *gin.Context) {
	ownerID, ok := currentUserID(c)
	if !ok {
		utils.Fail(c, http.StatusUnauthorized, "unauthenticated", nil)
		return
	}

	vehicleID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid vehicle id", err)
		return
	}

	var vehicle models.Vehicle
	if err := database.DB.First(&vehicle, "id = ?", vehicleID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "vehicle not found", nil)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch vehicle", err)
		return
	}

	if vehicle.OwnerID != ownerID {
		utils.Fail(c, http.StatusForbidden, "you do not own this vehicle", nil)
		return
	}

	var req UpdateVehicleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	if req.CapacityKg != nil {
		vehicle.CapacityKg = *req.CapacityKg
	}
	if req.BaseLocation != nil {
		vehicle.BaseLocation = *req.BaseLocation
	}
	if req.PricePerKm != nil {
		vehicle.PricePerKm = *req.PricePerKm
	}
	if req.Status != nil {
		vehicle.Status = models.VehicleStatus(*req.Status)
	}

	if err := database.DB.Save(&vehicle).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to update vehicle", err)
		return
	}

	utils.Success(c, http.StatusOK, "vehicle updated", vehicle)
}

func (h *LogisticsHandler) DeleteVehicle(c *gin.Context) {
	ownerID, ok := currentUserID(c)
	if !ok {
		utils.Fail(c, http.StatusUnauthorized, "unauthenticated", nil)
		return
	}

	vehicleID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid vehicle id", err)
		return
	}

	var vehicle models.Vehicle
	if err := database.DB.First(&vehicle, "id = ?", vehicleID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "vehicle not found", nil)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch vehicle", err)
		return
	}

	if vehicle.OwnerID != ownerID {
		utils.Fail(c, http.StatusForbidden, "you do not own this vehicle", nil)
		return
	}

	if err := database.DB.Delete(&vehicle).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to delete vehicle", err)
		return
	}

	utils.Success(c, http.StatusOK, "vehicle removed", nil)
}

// ---------- Freight Booking ----------

type CreateBookingRequest struct {
	VehicleID       string  `json:"vehicle_id" binding:"required,uuid"`
	PickupLocation  string  `json:"pickup_location" binding:"required,max=255"`
	DropLocation    string  `json:"drop_location" binding:"required,max=255"`
	CargoDetails    string  `json:"cargo_details" binding:"omitempty"`
	WeightKg        float64 `json:"weight_kg" binding:"required,gt=0"`
	ScheduledPickup string  `json:"scheduled_pickup" binding:"omitempty"` // RFC3339
}

func (h *LogisticsHandler) CreateBooking(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		utils.Fail(c, http.StatusUnauthorized, "unauthenticated", nil)
		return
	}

	var req CreateBookingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	vehicleID, err := uuid.Parse(req.VehicleID)
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid vehicle id", err)
		return
	}

	var booking models.Booking

	txErr := database.DB.Transaction(func(tx *gorm.DB) error {
		var vehicle models.Vehicle
		if err := tx.First(&vehicle, "id = ?", vehicleID).Error; err != nil {
			return err
		}
		if vehicle.Status != models.VehicleStatusAvailable {
			return errVehicleUnavailable
		}

		booking = models.Booking{
			VehicleID:      vehicleID,
			BookedByUserID: userID,
			PickupLocation: req.PickupLocation,
			DropLocation:   req.DropLocation,
			CargoDetails:   req.CargoDetails,
			WeightKg:       req.WeightKg,
			EstimatedCost:  vehicle.PricePerKm,
		}

		if req.ScheduledPickup != "" {
			t, err := time.Parse(time.RFC3339, req.ScheduledPickup)
			if err != nil {
				return errInvalidScheduledPickup
			}
			booking.ScheduledPickup = &t
		}

		if err := tx.Create(&booking).Error; err != nil {
			return err
		}

		return tx.Model(&vehicle).Update("status", models.VehicleStatusBooked).Error
	})

	if txErr != nil {
		switch {
		case errors.Is(txErr, gorm.ErrRecordNotFound):
			utils.Fail(c, http.StatusNotFound, "vehicle not found", nil)
		case errors.Is(txErr, errVehicleUnavailable):
			utils.Fail(c, http.StatusConflict, "vehicle is not available", nil)
		case errors.Is(txErr, errInvalidScheduledPickup):
			utils.Fail(c, http.StatusBadRequest, "invalid scheduled_pickup, use RFC3339 format", nil)
		default:
			utils.Fail(c, http.StatusInternalServerError, "failed to create booking", txErr)
		}
		return
	}

	utils.Success(c, http.StatusCreated, "booking created", booking)
}

var errVehicleUnavailable = errors.New("vehicle unavailable")
var errInvalidScheduledPickup = errors.New("invalid scheduled pickup")

func (h *LogisticsHandler) GetMyBookings(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		utils.Fail(c, http.StatusUnauthorized, "unauthenticated", nil)
		return
	}

	var bookings []models.Booking
	if err := database.DB.Preload("Vehicle").Where("booked_by_user_id = ?", userID).
		Order("created_at DESC").Find(&bookings).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch your bookings", err)
		return
	}

	utils.Success(c, http.StatusOK, "your bookings fetched", bookings)
}

func (h *LogisticsHandler) GetBooking(c *gin.Context) {
	bookingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid booking id", err)
		return
	}

	var booking models.Booking
	if err := database.DB.Preload("Vehicle").First(&booking, "id = ?", bookingID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "booking not found", nil)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch booking", err)
		return
	}

	utils.Success(c, http.StatusOK, "booking fetched", booking)
}

type UpdateBookingStatusRequest struct {
	Status string `json:"status" binding:"required,oneof=confirmed in_transit delivered cancelled"`
}

func (h *LogisticsHandler) UpdateBookingStatus(c *gin.Context) {
	bookingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid booking id", err)
		return
	}

	var req UpdateBookingStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	var booking models.Booking
	txErr := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.First(&booking, "id = ?", bookingID).Error; err != nil {
			return err
		}

		booking.Status = models.BookingStatus(req.Status)
		if err := tx.Save(&booking).Error; err != nil {
			return err
		}

		if req.Status == string(models.BookingStatusDelivered) || req.Status == string(models.BookingStatusCancelled) {
			return tx.Model(&models.Vehicle{}).Where("id = ?", booking.VehicleID).
				Update("status", models.VehicleStatusAvailable).Error
		}
		return nil
	})

	if txErr != nil {
		if errors.Is(txErr, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "booking not found", nil)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to update booking", txErr)
		return
	}

	utils.Success(c, http.StatusOK, "booking status updated", booking)
}
