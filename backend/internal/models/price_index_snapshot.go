package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// PriceIndexSnapshot is a point-in-time record of the live price index (see
// services.PriceIndexService), persisted so price history can be charted
// over time instead of only ever showing "right now". One row per
// (commodity_type, unit, source) per recording -- Source is "listing"
// (current asking prices) or "transacted" (actual order prices from the
// preceding 30 days); Unit keeps different measurement units (ton, kg, MT)
// from ever being blended into one misleading average, mirroring how
// services.PriceBand already separates them for the live index.
//
// No uniqueness constraint on day: if the recording job runs more than
// once on the same day (e.g. a server restart), that's simply an extra
// data point, not an error.
type PriceIndexSnapshot struct {
	ID            uuid.UUID     `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	CommodityType CommodityType `gorm:"type:varchar(30);not null;index" json:"commodity_type"`
	Unit          string        `gorm:"type:varchar(20);not null" json:"unit"`
	Source        string        `gorm:"type:varchar(20);not null" json:"source"` // "listing" | "transacted"

	AvgPrice   float64 `gorm:"not null" json:"avg_price"`
	MinPrice   float64 `gorm:"not null" json:"min_price"`
	MaxPrice   float64 `gorm:"not null" json:"max_price"`
	SampleSize int     `gorm:"not null" json:"sample_size"`

	RecordedAt time.Time `gorm:"not null;index" json:"recorded_at"`
	CreatedAt  time.Time `json:"created_at"`

	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (p *PriceIndexSnapshot) BeforeCreate(tx *gorm.DB) (err error) {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	return
}
