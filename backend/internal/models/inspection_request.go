package models

import (
"time"

"github.com/google/uuid"
"gorm.io/gorm"
)

type InspectionStatus string

const (
InspectionStatusPending   InspectionStatus = "pending"
InspectionStatusAssigned  InspectionStatus = "assigned"
InspectionStatusScheduled InspectionStatus = "scheduled"
InspectionStatusCompleted InspectionStatus = "completed"
InspectionStatusCancelled InspectionStatus = "cancelled"
)

type InspectionType string

const (
InspectionTypePreShipment  InspectionType = "pre_shipment"
InspectionTypePostDelivery InspectionType = "post_delivery"
)

type InspectionResult string

const (
InspectionResultPass        InspectionResult = "pass"
InspectionResultFail        InspectionResult = "fail"
InspectionResultConditional InspectionResult = "conditional"
)

type InspectionRequesterRole string

const (
InspectionRequesterBuyer  InspectionRequesterRole = "buyer"
InspectionRequesterSeller InspectionRequesterRole = "seller"
)

// InspectionRequest tracks a request for a quality inspection against an
// Order -- either pre-shipment (checking goods before they leave the
// seller) or post-delivery (checking goods on arrival). An admin assigns
// an inspector (a user with role "inspector"), who schedules a date and
// then submits a pass/fail/conditional report.
type InspectionRequest struct {
ID            uuid.UUID               `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
OrderID       uuid.UUID               `gorm:"type:uuid;not null;index" json:"order_id"`
RequesterID   uuid.UUID               `gorm:"type:uuid;not null;index" json:"requester_id"`
RequesterRole InspectionRequesterRole `gorm:"type:varchar(10);not null" json:"requester_role"`

InspectionType InspectionType `gorm:"type:varchar(20);not null" json:"inspection_type"`
Notes          string         `gorm:"type:varchar(1000)" json:"notes,omitempty"`

Status InspectionStatus `gorm:"type:varchar(20);not null;default:'pending';index" json:"status"`

InspectorID   *uuid.UUID `gorm:"type:uuid;index" json:"inspector_id,omitempty"`
ScheduledDate *time.Time `json:"scheduled_date,omitempty"`

Result        InspectionResult `gorm:"type:varchar(20)" json:"result,omitempty"`
Grade         string           `gorm:"type:varchar(50)" json:"grade,omitempty"`
ReportNotes   string           `gorm:"type:varchar(1000)" json:"report_notes,omitempty"`
ReportFileURL string           `gorm:"type:varchar(500)" json:"report_file_url,omitempty"`
CompletedAt   *time.Time       `json:"completed_at,omitempty"`

CreatedAt time.Time      `json:"created_at"`
DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (i *InspectionRequest) BeforeCreate(tx *gorm.DB) (err error) {
if i.ID == uuid.Nil {
i.ID = uuid.New()
}
if i.Status == "" {
i.Status = InspectionStatusPending
}
return
}