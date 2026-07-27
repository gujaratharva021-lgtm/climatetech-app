package handlers

import (
	"errors"
	"net/http"
	"time"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type KYCHandler struct{}

func NewKYCHandler() *KYCHandler {
	return &KYCHandler{}
}

type SubmitKYCRequest struct {
	DocumentType     string `json:"document_type" binding:"required,oneof=aadhaar pan gst"`
	DocumentNumber   string `json:"document_number" binding:"required,min=4,max=50"`
	DocumentPhotoURL string `json:"document_photo_url" binding:"required,url"`
	SelfiePhotoURL   string `json:"selfie_photo_url" binding:"omitempty,url"`
}

func currentUserID(c *gin.Context) (uuid.UUID, bool) {
	val, exists := c.Get("user_id")
	if !exists {
		return uuid.Nil, false
	}
	id, ok := val.(uuid.UUID)
	return id, ok
}

// SubmitKYC creates or resubmits the caller's KYC verification. Verification
// is auto-approved immediately on submit — there is no manual admin review
// step in this flow. This means the "verified" badge only confirms a
// document was uploaded, not that it was actually checked against any
// government record; ListPendingKYC/ApproveKYC/RejectKYC below are left in
// place so manual review can be turned back on later without rebuilding it.
func (h *KYCHandler) SubmitKYC(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		utils.Fail(c, http.StatusUnauthorized, "unauthenticated", nil)
		return
	}

	var req SubmitKYCRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	now := time.Now()

	var existing models.KYCVerification
	err := database.DB.Where("user_id = ?", userID).First(&existing).Error
	if err == nil {
		existing.DocumentType = models.KYCDocumentType(req.DocumentType)
		existing.DocumentNumber = req.DocumentNumber
		existing.DocumentPhotoURL = req.DocumentPhotoURL
		existing.SelfiePhotoURL = req.SelfiePhotoURL
		existing.Status = models.KYCStatusVerified
		existing.RejectionReason = ""
		existing.ReviewedBy = nil
		existing.ReviewedAt = &now

		if err := database.DB.Save(&existing).Error; err != nil {
			utils.Fail(c, http.StatusInternalServerError, "failed to resubmit verification", err)
			return
		}
	} else if errors.Is(err, gorm.ErrRecordNotFound) {
		kyc := models.KYCVerification{
			UserID:           userID,
			DocumentType:     models.KYCDocumentType(req.DocumentType),
			DocumentNumber:   req.DocumentNumber,
			DocumentPhotoURL: req.DocumentPhotoURL,
			SelfiePhotoURL:   req.SelfiePhotoURL,
			Status:           models.KYCStatusVerified,
			ReviewedAt:       &now,
		}
		if err := database.DB.Create(&kyc).Error; err != nil {
			utils.Fail(c, http.StatusInternalServerError, "failed to submit verification", err)
			return
		}
		existing = kyc
	} else {
		utils.Fail(c, http.StatusInternalServerError, "failed to check existing verification", err)
		return
	}

	if err := database.DB.Model(&models.User{}).Where("id = ?", userID).
		Update("kyc_status", models.KYCStatusVerified).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to update account status", err)
		return
	}

	utils.Success(c, http.StatusCreated, "verification submitted and verified", existing)
}

// GetMyKYC returns the caller's own verification record.
func (h *KYCHandler) GetMyKYC(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		utils.Fail(c, http.StatusUnauthorized, "unauthenticated", nil)
		return
	}

	var kyc models.KYCVerification
	if err := database.DB.Where("user_id = ?", userID).First(&kyc).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Success(c, http.StatusOK, "no verification submitted yet", gin.H{"status": models.KYCStatusNotSubmitted})
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch verification", err)
		return
	}

	utils.Success(c, http.StatusOK, "verification fetched", kyc)
}

// ListPendingKYC, ApproveKYC, RejectKYC are kept for a future manual-review
// mode but are unreachable in normal operation now, since SubmitKYC no
// longer leaves anything in "pending" status.
func (h *KYCHandler) ListPendingKYC(c *gin.Context) {
	page, limit, offset := utils.ParsePageLimit(c, 20, 100)

	var records []models.KYCVerification
	var total int64

	query := database.DB.Model(&models.KYCVerification{}).Where("status = ?", models.KYCStatusPending)
	if err := query.Count(&total).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count pending verifications", err)
		return
	}
	if err := query.Order("created_at ASC").
		Offset(offset).Limit(limit).
		Find(&records).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch pending verifications", err)
		return
	}

	utils.Success(c, http.StatusOK, "pending verifications fetched", gin.H{
		"page": page, "limit": limit, "total": total, "verifications": records,
	})
}

type ReviewKYCRequest struct {
	RejectionReason string `json:"rejection_reason" binding:"omitempty,max=500"`
}

func (h *KYCHandler) ApproveKYC(c *gin.Context) {
	h.review(c, models.KYCStatusVerified, "")
}

func (h *KYCHandler) RejectKYC(c *gin.Context) {
	var req ReviewKYCRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}
	if req.RejectionReason == "" {
		utils.Fail(c, http.StatusBadRequest, "rejection_reason is required", nil)
		return
	}
	h.review(c, models.KYCStatusRejected, req.RejectionReason)
}

func (h *KYCHandler) review(c *gin.Context, outcome models.KYCStatus, rejectionReason string) {
	idParam := c.Param("id")
	kycID, err := uuid.Parse(idParam)
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid verification id", err)
		return
	}

	adminIDVal, ok := currentUserID(c)
	if !ok {
		utils.Fail(c, http.StatusUnauthorized, "unauthenticated", nil)
		return
	}

	var kyc models.KYCVerification
	if err := database.DB.First(&kyc, "id = ?", kycID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "verification not found", nil)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch verification", err)
		return
	}

	if kyc.Status != models.KYCStatusPending {
		utils.Fail(c, http.StatusConflict, "verification has already been reviewed", nil)
		return
	}

	now := time.Now()
	kyc.Status = outcome
	kyc.ReviewedBy = &adminIDVal
	kyc.ReviewedAt = &now
	if outcome == models.KYCStatusRejected {
		kyc.RejectionReason = rejectionReason
	}

	txErr := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Save(&kyc).Error; err != nil {
			return err
		}
		return tx.Model(&models.User{}).Where("id = ?", kyc.UserID).
			Update("kyc_status", outcome).Error
	})
	if txErr != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to record review decision", txErr)
		return
	}

	utils.Success(c, http.StatusOK, "verification reviewed", kyc)
}
