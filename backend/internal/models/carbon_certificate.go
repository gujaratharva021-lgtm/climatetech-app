package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type CertificateStatus string

const (
	CertificateStatusActive       CertificateStatus = "active"
	CertificateStatusFullyRetired CertificateStatus = "fully_retired"
)

// CarbonCreditCertificate represents a specific registry-issued batch of
// carbon credits (a serial number range from a real registry like Verra or
// Gold Standard) that a seller owns and lists for sale. This is a TRACKING
// record, not a registry integration -- becoming an accredited participant
// in a real registry's API (to verify issuance or record retirements
// there) is a separate, much larger undertaking requiring the platform
// itself to be accredited, same reasoning as trade finance not connecting
// to a real bank/NBFC API. What this DOES guarantee correctly: a credit
// tracked here can never be retired for more than its remaining quantity,
// and once retired, there is no "un-retire" path anywhere in this codebase
// -- see CreditRetirement.
type CarbonCreditCertificate struct {
	ID        uuid.UUID  `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	SellerID  uuid.UUID  `gorm:"type:uuid;not null;index" json:"seller_id"`
	ListingID *uuid.UUID `gorm:"type:uuid;index" json:"listing_id,omitempty"`

	// Registry/ProjectType are free text rather than DB-enforced enums --
	// unlike CommodityType or Status, the set of registries and project
	// methodologies isn't fixed or fully known up front, and new ones
	// appear as this market evolves.
	Registry          string `gorm:"type:varchar(100);not null" json:"registry"` // e.g. "Verra", "Gold Standard"
	ProjectName       string `gorm:"type:varchar(200);not null" json:"project_name"`
	ProjectID         string `gorm:"type:varchar(100)" json:"project_id"`  // the registry's own project reference
	ProjectType       string `gorm:"type:varchar(50)" json:"project_type"` // e.g. "renewable_energy", "reforestation"
	VintageYear       int    `gorm:"not null" json:"vintage_year"`         // year the emission reduction/removal occurred
	SerialNumberRange string `gorm:"type:varchar(200)" json:"serial_number_range"`

	TotalQuantity     float64 `gorm:"not null" json:"total_quantity"`     // tCO2e
	RemainingQuantity float64 `gorm:"not null" json:"remaining_quantity"` // tCO2e not yet retired

	Status CertificateStatus `gorm:"type:varchar(20);not null;default:'active';index" json:"status"`

	CreatedAt time.Time      `json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (cc *CarbonCreditCertificate) BeforeCreate(tx *gorm.DB) (err error) {
	if cc.ID == uuid.Nil {
		cc.ID = uuid.New()
	}
	if cc.Status == "" {
		cc.Status = CertificateStatusActive
	}
	if cc.RemainingQuantity == 0 {
		cc.RemainingQuantity = cc.TotalQuantity
	}
	return
}

// CreditRetirement is the permanent record of a buyer claiming (retiring)
// a quantity of credits from a Certificate -- the moment the environmental
// benefit is actually claimed and the credit must never be resold or
// counted again. There is deliberately NO soft-delete (no DeletedAt field)
// and no update/undo endpoint anywhere in this codebase for this model:
// once created, a retirement record is permanent, matching how retirement
// works on every real carbon registry.
type CreditRetirement struct {
	ID              uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	CertificateID   uuid.UUID `gorm:"type:uuid;not null;index" json:"certificate_id"`
	RetiredByUserID uuid.UUID `gorm:"type:uuid;not null;index" json:"retired_by_user_id"`

	Quantity         float64 `gorm:"not null" json:"quantity"`
	BeneficiaryName  string  `gorm:"type:varchar(200)" json:"beneficiary_name"`
	RetirementReason string  `gorm:"type:varchar(500)" json:"retirement_reason"`

	// ReferenceNumber is a locally-generated display reference, not a real
	// registry retirement certificate number -- see the type doc comment.
	ReferenceNumber string `gorm:"type:varchar(100);not null;uniqueIndex" json:"reference_number"`

	CreatedAt time.Time `json:"created_at"`
}

func (r *CreditRetirement) BeforeCreate(tx *gorm.DB) (err error) {
	if r.ID == uuid.Nil {
		r.ID = uuid.New()
	}
	return
}
