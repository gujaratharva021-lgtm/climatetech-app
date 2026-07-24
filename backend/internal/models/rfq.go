package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// RFQStatus tracks an RFQ through the reverse-auction lifecycle: open for
// bids, awarded once the buyer accepts one, cancelled by the buyer, or
// expired once its deadline passes without an award.
type RFQStatus string

const (
	RFQStatusOpen      RFQStatus = "open"
	RFQStatusAwarded   RFQStatus = "awarded"
	RFQStatusCancelled RFQStatus = "cancelled"
	RFQStatusExpired   RFQStatus = "expired"
)

// RFQ (Request For Quote) is a buyer's posted requirement — sellers respond
// with Bids, and the buyer accepts one to award it (see AcceptBid in
// rfq_handler.go). This is the reverse-auction counterpart to Listing:
// Listing is "seller posts what they have", RFQ is "buyer posts what they need".
type RFQ struct {
	ID            uuid.UUID     `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	BuyerID       uuid.UUID     `gorm:"type:uuid;not null;index" json:"buyer_id"`
	CommodityType CommodityType `gorm:"type:varchar(30);not null;default:'other';index" json:"commodity_type"`
	Quantity      float64       `gorm:"not null" json:"quantity"`
	Unit          string        `gorm:"type:varchar(20);not null;default:'unit'" json:"unit"`

	// TargetPrice is the buyer's optional target price per unit. Zero means
	// the buyer didn't specify one and is open to seller offers — it's not
	// itself a binding price, just a signal to sellers deciding whether to bid.
	TargetPrice float64 `gorm:"not null;default:0" json:"target_price"`

	Grade    string `gorm:"type:varchar(500)" json:"grade"`
	Location string `gorm:"type:varchar(150)" json:"location"`

	Deadline time.Time `gorm:"not null;index" json:"deadline"`
	Status   RFQStatus `gorm:"type:varchar(20);not null;default:'open';index" json:"status"`

	// AwardedBidID is set once the buyer accepts a bid (see AcceptBid). Left
	// nil otherwise. No DB-level FK to bids — same no-FK convention this
	// project already uses between listings and sellers.
	AwardedBidID *uuid.UUID `gorm:"type:uuid" json:"awarded_bid_id"`

	CreatedAt time.Time      `json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (r *RFQ) BeforeCreate(tx *gorm.DB) (err error) {
	if r.ID == uuid.Nil {
		r.ID = uuid.New()
	}
	if r.Status == "" {
		r.Status = RFQStatusOpen
	}
	if r.Unit == "" {
		r.Unit = "unit"
	}
	if r.CommodityType == "" {
		r.CommodityType = CommodityOther
	}
	return
}
