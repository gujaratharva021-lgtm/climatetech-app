package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// BidStatus tracks a bid through the reverse-auction lifecycle. Exactly one
// bid per RFQ can end up "accepted" — see RFQHandler.AcceptBid, which moves
// the winning bid to accepted and every other pending bid on the same RFQ to
// rejected inside a single transaction.
type BidStatus string

const (
	BidStatusPending   BidStatus = "pending"
	BidStatusAccepted  BidStatus = "accepted"
	BidStatusRejected  BidStatus = "rejected"
	BidStatusWithdrawn BidStatus = "withdrawn"
)

// Bid is a seller's offer against a specific RFQ.
type Bid struct {
	ID       uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	RFQID    uuid.UUID `gorm:"type:uuid;not null;index" json:"rfq_id"`
	SellerID uuid.UUID `gorm:"type:uuid;not null;index" json:"seller_id"`

	Price    float64 `gorm:"not null" json:"price"`    // per unit, in the RFQ's Unit
	Quantity float64 `gorm:"not null" json:"quantity"` // quantity the seller can supply

	Message string    `gorm:"type:varchar(1000)" json:"message"`
	Status  BidStatus `gorm:"type:varchar(20);not null;default:'pending';index" json:"status"`

	CreatedAt time.Time      `json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (b *Bid) BeforeCreate(tx *gorm.DB) (err error) {
	if b.ID == uuid.Nil {
		b.ID = uuid.New()
	}
	if b.Status == "" {
		b.Status = BidStatusPending
	}
	return
}
