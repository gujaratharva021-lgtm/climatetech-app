package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type ListingCondition string

const (
	ConditionNew  ListingCondition = "new"
	ConditionUsed ListingCondition = "used"
)

// CommodityType classifies a listing for the energy commodity marketplace.
// "other" is the default/fallback for listings that predate this field or
// don't fit the named energy commodities (kept so existing generic
// classified-ad listings don't need backfilling to stay valid).
type CommodityType string

const (
	CommodityCoal         CommodityType = "coal"
	CommodityBiomass      CommodityType = "biomass"
	CommodityCoke         CommodityType = "coke"
	CommodityCarbonCredit CommodityType = "carbon_credit"
	CommodityOther        CommodityType = "other"
)

// Valid reports whether c is one of the known commodity types.
func (c CommodityType) Valid() bool {
	switch c {
	case CommodityCoal, CommodityBiomass, CommodityCoke, CommodityCarbonCredit, CommodityOther:
		return true
	}
	return false
}

// Listing is a single marketplace listing, owned by a Seller. Originally a
// generic classified ad (Price/Condition/ImageURLs), extended in place with
// bulk-trade fields (CommodityType/Quantity/Unit/MinOrderQty/Grade) so energy
// commodity listings (coal, biomass, coke, carbon credit) live in the same
// table instead of a parallel model.
type Listing struct {
	ID          uuid.UUID        `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	SellerID    uuid.UUID        `gorm:"type:uuid;not null;index" json:"seller_id"`
	Title       string           `gorm:"type:varchar(200);not null" json:"title"`
	Description string           `gorm:"type:text" json:"description"`
	Category    string           `gorm:"type:varchar(50);not null;index" json:"category"`
	ImageURLs   StringArray      `gorm:"type:text" json:"image_urls"`
	Condition   ListingCondition `gorm:"type:varchar(10);not null;default:'used'" json:"condition"`
	Location    string           `gorm:"type:varchar(150)" json:"location"`
	IsActive    bool             `gorm:"not null;default:true;index" json:"is_active"`

	// Price is price per unit for commodity listings (Unit below defines
	// what "unit" means — ton, kg, MT, etc.), and the flat item price for
	// generic classified-ad listings where Unit is left as "unit".
	Price float64 `gorm:"not null" json:"price"`

	// --- Commodity trading fields ---
	CommodityType CommodityType `gorm:"type:varchar(30);not null;default:'other';index" json:"commodity_type"`
	Quantity      float64       `gorm:"not null;default:0" json:"quantity"`                   // total quantity available, in Unit
	Unit          string        `gorm:"type:varchar(20);not null;default:'unit'" json:"unit"` // e.g. "ton", "kg", "MT", "unit"
	MinOrderQty   float64       `gorm:"not null;default:0" json:"min_order_qty"`              // minimum quantity a buyer can order, in Unit
	Grade         string        `gorm:"type:varchar(500)" json:"grade"`                       // free-text quality spec, e.g. "GCV 4200 kcal/kg, Ash <15%"

	CreatedAt time.Time      `json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (l *Listing) BeforeCreate(tx *gorm.DB) (err error) {
	if l.ID == uuid.Nil {
		l.ID = uuid.New()
	}
	if l.Condition == "" {
		l.Condition = ConditionUsed
	}
	if l.CommodityType == "" {
		l.CommodityType = CommodityOther
	}
	if l.Unit == "" {
		l.Unit = "unit"
	}
	return
}
