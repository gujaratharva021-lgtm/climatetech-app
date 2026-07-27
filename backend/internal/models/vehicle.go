package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type VehicleType string

const (
	VehicleTruck     VehicleType = "truck"
	VehicleTrailer   VehicleType = "trailer"
	VehicleMiniVan   VehicleType = "mini_van"
	VehicleContainer VehicleType = "container"
)

type VehicleStatus string

const (
	VehicleStatusAvailable   VehicleStatus = "available"
	VehicleStatusBooked      VehicleStatus = "booked"
	VehicleStatusMaintenance VehicleStatus = "maintenance"
	VehicleStatusInactive    VehicleStatus = "inactive"
)

// Vehicle is a freight vehicle listed by an owner for booking in the
// logistics marketplace. Availability is tracked via Status rather than a
// separate calendar table — a vehicle is either available or it isn't,
// there's no support yet for scheduling multiple future bookings on the
// same vehicle.
type Vehicle struct {
	ID           uuid.UUID     `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	OwnerID      uuid.UUID     `gorm:"type:uuid;not null;index" json:"owner_id"`
	VehicleType  VehicleType   `gorm:"type:varchar(30);not null" json:"vehicle_type"`
	RegNumber    string        `gorm:"type:varchar(50);not null;uniqueIndex" json:"reg_number"`
	CapacityKg   float64       `gorm:"type:numeric(10,2);not null;default:0" json:"capacity_kg"`
	CapacityUnit string        `gorm:"type:varchar(10);not null;default:'kg'" json:"capacity_unit"`
	BaseLocation string        `gorm:"type:varchar(255)" json:"base_location,omitempty"`
	PricePerKm   float64       `gorm:"type:numeric(10,2);not null;default:0" json:"price_per_km"`
	Status       VehicleStatus `gorm:"type:varchar(20);not null;default:'available';index" json:"status"`

	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (v *Vehicle) BeforeCreate(tx *gorm.DB) (err error) {
	if v.ID == uuid.Nil {
		v.ID = uuid.New()
	}
	if v.Status == "" {
		v.Status = VehicleStatusAvailable
	}
	if v.CapacityUnit == "" {
		v.CapacityUnit = "kg"
	}
	return
}
