package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type BookingStatus string

const (
	BookingStatusPending   BookingStatus = "pending"
	BookingStatusConfirmed BookingStatus = "confirmed"
	BookingStatusInTransit BookingStatus = "in_transit"
	BookingStatusDelivered BookingStatus = "delivered"
	BookingStatusCancelled BookingStatus = "cancelled"
)

// Booking is a freight request against a specific Vehicle. Creating a
// booking marks the vehicle "booked" so it can't be double-booked;
// delivering or cancelling a booking frees the vehicle back to
// "available" (see LogisticsHandler).
type Booking struct {
	ID              uuid.UUID     `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	VehicleID       uuid.UUID     `gorm:"type:uuid;not null;index" json:"vehicle_id"`
	Vehicle         *Vehicle      `gorm:"foreignKey:VehicleID" json:"vehicle,omitempty"`
	BookedByUserID  uuid.UUID     `gorm:"type:uuid;not null;index" json:"booked_by_user_id"`
	PickupLocation  string        `gorm:"type:varchar(255);not null" json:"pickup_location"`
	DropLocation    string        `gorm:"type:varchar(255);not null" json:"drop_location"`
	CargoDetails    string        `gorm:"type:text" json:"cargo_details,omitempty"`
	WeightKg        float64       `gorm:"type:numeric(10,2);not null;default:0" json:"weight_kg"`
	ScheduledPickup *time.Time    `json:"scheduled_pickup,omitempty"`
	Status          BookingStatus `gorm:"type:varchar(20);not null;default:'pending';index" json:"status"`
	EstimatedCost   float64       `gorm:"type:numeric(10,2);not null;default:0" json:"estimated_cost"`

	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (b *Booking) BeforeCreate(tx *gorm.DB) (err error) {
	if b.ID == uuid.Nil {
		b.ID = uuid.New()
	}
	if b.Status == "" {
		b.Status = BookingStatusPending
	}
	return
}
