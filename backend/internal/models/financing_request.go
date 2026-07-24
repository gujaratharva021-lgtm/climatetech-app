package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// FinancingStatus is an explicit state machine, not a free-text field --
// see FinancingHandler.isAllowedFinancingTransition for exactly which
// moves are legal (e.g. "pending" can never jump straight to "repaid").
type FinancingStatus string

const (
	FinancingStatusPending     FinancingStatus = "pending"
	FinancingStatusUnderReview FinancingStatus = "under_review"
	FinancingStatusApproved    FinancingStatus = "approved"
	FinancingStatusRejected    FinancingStatus = "rejected"
	FinancingStatusDisbursed   FinancingStatus = "disbursed"
	FinancingStatusRepaid      FinancingStatus = "repaid"
	FinancingStatusDefaulted   FinancingStatus = "defaulted"
)

// FinancingRequesterRole records which side of the Order asked for
// financing: the buyer (seeking working capital) or the seller (seeking
// early payment / invoice discounting) -- same order, different financing
// products in the real world, worth distinguishing even though this
// tracking system doesn't yet act differently based on it.
type FinancingRequesterRole string

const (
	FinancingRequesterBuyer  FinancingRequesterRole = "buyer"
	FinancingRequesterSeller FinancingRequesterRole = "seller"
)

// FinancingRequest tracks a request to finance (discount) an Order's
// invoice value. This is a TRACKING system, not a lending integration:
// there is no automated underwriting and no real fund disbursal here.
// Real invoice-financing lenders (banks, NBFCs, TReDS platforms) each have
// their own proprietary API, and getting access to any of them requires an
// actual business partnership -- not something to fake with a generic
// connector. An admin (standing in for a human ops team, or a future real
// lender-API integration slotted in later) reviews and moves the request
// through the status states manually.
type FinancingRequest struct {
	ID            uuid.UUID              `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	OrderID       uuid.UUID              `gorm:"type:uuid;not null;index" json:"order_id"`
	RequesterID   uuid.UUID              `gorm:"type:uuid;not null;index" json:"requester_id"`
	RequesterRole FinancingRequesterRole `gorm:"type:varchar(10);not null" json:"requester_role"`

	RequestedAmount float64 `gorm:"not null" json:"requested_amount"`
	Purpose         string  `gorm:"type:varchar(500)" json:"purpose"`

	Status FinancingStatus `gorm:"type:varchar(20);not null;default:'pending';index" json:"status"`

	// Filled in by an admin during review; zero/empty until then.
	LenderName     string  `gorm:"type:varchar(150)" json:"lender_name,omitempty"`
	ApprovedAmount float64 `gorm:"default:0" json:"approved_amount,omitempty"`
	InterestRate   float64 `gorm:"default:0" json:"interest_rate,omitempty"` // annualized %, informational only
	AdminNotes     string  `gorm:"type:varchar(1000)" json:"admin_notes,omitempty"`

	DisbursedAt *time.Time `json:"disbursed_at,omitempty"`
	RepaidAt    *time.Time `json:"repaid_at,omitempty"`

	CreatedAt time.Time      `json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (f *FinancingRequest) BeforeCreate(tx *gorm.DB) (err error) {
	if f.ID == uuid.Nil {
		f.ID = uuid.New()
	}
	if f.Status == "" {
		f.Status = FinancingStatusPending
	}
	return
}
