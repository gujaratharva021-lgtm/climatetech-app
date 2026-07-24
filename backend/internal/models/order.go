package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// OrderSource records which flow created the order: an awarded RFQ bid
// (reverse auction) or a direct purchase against a Listing. Exactly one of
// (RFQID+BidID) or ListingID is set, matching Source.
type OrderSource string

const (
	OrderSourceRFQ     OrderSource = "rfq"
	OrderSourceListing OrderSource = "listing"
)

// OrderStatus tracks fulfillment. Linear happy path is
// placed -> confirmed -> shipped -> delivered; cancellation is only allowed
// from "placed" (see OrderHandler.CancelOrder) — once a seller has confirmed,
// cancelling needs a real conversation, not a one-click API call.
type OrderStatus string

const (
	OrderStatusPlaced    OrderStatus = "placed"
	OrderStatusConfirmed OrderStatus = "confirmed"
	OrderStatusShipped   OrderStatus = "shipped"
	OrderStatusDelivered OrderStatus = "delivered"
	OrderStatusCancelled OrderStatus = "cancelled"
)

// Order is the fulfillment record created once a trade is agreed — either
// by the buyer accepting an RFQ bid, or by a direct purchase against a
// Listing. This is the anchor Phase 4 (payment/escrow) and Phase 5
// (logistics/shipment tracking) will build on.
type Order struct {
	ID       uuid.UUID   `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	BuyerID  uuid.UUID   `gorm:"type:uuid;not null;index" json:"buyer_id"`
	SellerID uuid.UUID   `gorm:"type:uuid;not null;index" json:"seller_id"` // Seller.ID, not User.ID
	Source   OrderSource `gorm:"type:varchar(20);not null" json:"source"`

	// Exactly one of these two pairs is populated, per Source. No DB-level
	// FKs, matching this project's existing convention.
	RFQID     *uuid.UUID `gorm:"type:uuid;index" json:"rfq_id,omitempty"`
	BidID     *uuid.UUID `gorm:"type:uuid" json:"bid_id,omitempty"`
	ListingID *uuid.UUID `gorm:"type:uuid;index" json:"listing_id,omitempty"`

	CommodityType CommodityType `gorm:"type:varchar(30);not null;default:'other'" json:"commodity_type"`
	Quantity      float64       `gorm:"not null" json:"quantity"`
	Unit          string        `gorm:"type:varchar(20);not null;default:'unit'" json:"unit"`
	PricePerUnit  float64       `gorm:"not null" json:"price_per_unit"`
	TotalAmount   float64       `gorm:"not null" json:"total_amount"`

	DeliveryAddress string      `gorm:"type:varchar(500);not null" json:"delivery_address"`
	Status          OrderStatus `gorm:"type:varchar(20);not null;default:'placed';index" json:"status"`

	CreatedAt time.Time      `json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (o *Order) BeforeCreate(tx *gorm.DB) (err error) {
	if o.ID == uuid.Nil {
		o.ID = uuid.New()
	}
	if o.Status == "" {
		o.Status = OrderStatusPlaced
	}
	if o.Unit == "" {
		o.Unit = "unit"
	}
	if o.CommodityType == "" {
		o.CommodityType = CommodityOther
	}
	if o.TotalAmount == 0 {
		o.TotalAmount = o.Quantity * o.PricePerUnit
	}
	return
}
