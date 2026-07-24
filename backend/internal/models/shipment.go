package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ShipmentStatus tracks physical logistics progress, separate from
// Order.Status (which tracks the business/fulfillment state). Deliberately
// kept separate: a seller updating shipment status doesn't itself confirm
// delivery on the order -- that's still the buyer's call via
// OrderHandler.DeliverOrder, matching how Phase 3 already draws that line.
type ShipmentStatus string

const (
	ShipmentStatusPending    ShipmentStatus = "pending"    // record created, not yet dispatched
	ShipmentStatusDispatched ShipmentStatus = "dispatched" // left the seller's location
	ShipmentStatusInTransit  ShipmentStatus = "in_transit"
	ShipmentStatusDelivered  ShipmentStatus = "delivered"
	ShipmentStatusFailed     ShipmentStatus = "failed" // delivery attempt failed, lost, or returned
)

// Shipment is the logistics record for an Order -- carrier/vehicle/driver
// details, a manually-updated status and current location (no real carrier
// API integrated yet, per the original plan's Phase 5 scope), and proof of
// delivery once it arrives. One shipment per order.
type Shipment struct {
	ID      uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	OrderID uuid.UUID `gorm:"type:uuid;not null;uniqueIndex" json:"order_id"`

	CarrierName    string `gorm:"type:varchar(150);not null" json:"carrier_name"`
	VehicleNumber  string `gorm:"type:varchar(50)" json:"vehicle_number"`
	DriverName     string `gorm:"type:varchar(150)" json:"driver_name"`
	DriverPhone    string `gorm:"type:varchar(20)" json:"driver_phone"`
	TrackingNumber string `gorm:"type:varchar(100)" json:"tracking_number"`

	CurrentLocation       string         `gorm:"type:varchar(200)" json:"current_location"`
	Status                ShipmentStatus `gorm:"type:varchar(20);not null;default:'pending';index" json:"status"`
	EstimatedDeliveryDate *time.Time     `json:"estimated_delivery_date,omitempty"`
	ProofOfDeliveryURL    string         `gorm:"type:varchar(500)" json:"proof_of_delivery_url,omitempty"`

	CreatedAt time.Time      `json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (s *Shipment) BeforeCreate(tx *gorm.DB) (err error) {
	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	if s.Status == "" {
		s.Status = ShipmentStatusPending
	}
	return
}
