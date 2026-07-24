package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// PaymentStatus tracks escrow state for an Order's payment:
// created (Razorpay order created, awaiting checkout) -> paid (captured,
// funds held in escrow in this platform's Razorpay account) -> released
// (paid out to the seller -- see PaymentHandler.ReleaseEscrow's doc comment
// for the real-money caveat) or refunded. failed covers an attempt that
// never completed.
type PaymentStatus string

const (
	PaymentStatusCreated  PaymentStatus = "created"
	PaymentStatusPaid     PaymentStatus = "paid"
	PaymentStatusReleased PaymentStatus = "released"
	PaymentStatusRefunded PaymentStatus = "refunded"
	PaymentStatusFailed   PaymentStatus = "failed"
)

// Payment is the escrow record for an Order. An order can have more than
// one Payment row over time (e.g. a "created" attempt the buyer abandoned,
// followed by a fresh one that succeeded) -- callers needing "the" payment
// for an order should query by status and/or order by created_at DESC, as
// PaymentHandler does throughout.
type Payment struct {
	ID      uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	OrderID uuid.UUID `gorm:"type:uuid;not null;index" json:"order_id"`

	RazorpayOrderID   string `gorm:"type:varchar(100);not null;index" json:"razorpay_order_id"`
	RazorpayPaymentID string `gorm:"type:varchar(100)" json:"razorpay_payment_id,omitempty"`
	RazorpaySignature string `gorm:"type:varchar(255)" json:"-"` // never serialized back to a client
	RefundID          string `gorm:"type:varchar(100)" json:"refund_id,omitempty"`

	Amount   float64       `gorm:"not null" json:"amount"` // rupees
	Currency string        `gorm:"type:varchar(10);not null;default:'INR'" json:"currency"`
	Status   PaymentStatus `gorm:"type:varchar(20);not null;default:'created';index" json:"status"`

	CreatedAt time.Time      `json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (p *Payment) BeforeCreate(tx *gorm.DB) (err error) {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	if p.Status == "" {
		p.Status = PaymentStatusCreated
	}
	if p.Currency == "" {
		p.Currency = "INR"
	}
	return
}
