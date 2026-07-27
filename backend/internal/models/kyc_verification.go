package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type KYCDocumentType string

const (
	KYCDocAadhaar KYCDocumentType = "aadhaar"
	KYCDocPAN     KYCDocumentType = "pan"
	KYCDocGST     KYCDocumentType = "gst"
)

type KYCStatus string

const (
	KYCStatusNotSubmitted KYCStatus = "not_submitted"
	KYCStatusPending      KYCStatus = "pending"
	KYCStatusVerified     KYCStatus = "verified"
	KYCStatusRejected     KYCStatus = "rejected"
)

// KYCVerification is a user's identity-document submission, subject to
// manual admin review. This is deliberately a document-upload + human-review
// flow rather than a live UIDAI e-KYC integration — verifying an Aadhaar
// number against the government database requires a licensed AUA/KUA
// agreement with UIDAI, which is a legal/business prerequisite no amount of
// application code can substitute for. At most one submission record is kept
// per user (a rejected user resubmits by updating this same row), so the
// full history of what was rejected and why isn't lost on retry.
type KYCVerification struct {
	ID               uuid.UUID       `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID           uuid.UUID       `gorm:"type:uuid;not null;uniqueIndex" json:"user_id"`
	DocumentType     KYCDocumentType `gorm:"type:varchar(20);not null" json:"document_type"`
	DocumentNumber   string          `gorm:"type:varchar(50);not null" json:"document_number"`
	DocumentPhotoURL string          `gorm:"type:varchar(500);not null" json:"document_photo_url"`
	SelfiePhotoURL   string          `gorm:"type:varchar(500)" json:"selfie_photo_url,omitempty"`
	Status           KYCStatus       `gorm:"type:varchar(20);not null;default:'pending';index" json:"status"`
	RejectionReason  string          `gorm:"type:varchar(500)" json:"rejection_reason,omitempty"`
	ReviewedBy       *uuid.UUID      `gorm:"type:uuid" json:"reviewed_by,omitempty"`
	ReviewedAt       *time.Time      `json:"reviewed_at,omitempty"`

	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (k *KYCVerification) BeforeCreate(tx *gorm.DB) (err error) {
	if k.ID == uuid.Nil {
		k.ID = uuid.New()
	}
	if k.Status == "" {
		k.Status = KYCStatusPending
	}
	return
}

// MaskedDocumentNumber returns the document number with all but the last 4
// characters redacted, for any response path that isn't the owning user or
// an admin reviewing the submission — Aadhaar/PAN numbers are sensitive PII
// that shouldn't be echoed back in full outside those two contexts.
func (k *KYCVerification) MaskedDocumentNumber() string {
	n := k.DocumentNumber
	if len(n) <= 4 {
		return "****"
	}
	masked := ""
	for i := 0; i < len(n)-4; i++ {
		masked += "*"
	}
	return masked + n[len(n)-4:]
}
