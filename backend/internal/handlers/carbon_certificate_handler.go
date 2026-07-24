package handlers

import (
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

var (
	errCertConflict              = errors.New("certificate not attached to a listing")
	errCertInsufficientRemaining = errors.New("insufficient remaining credits")
	errCertInsufficientPurchased = errors.New("insufficient purchased-and-unretired credits")
	errCertAlreadyAttached       = errors.New("certificate already attached")
	errCertListingCommodityWrong = errors.New("listing is not a carbon credit listing")
)

type CarbonCertificateHandler struct{}

func NewCarbonCertificateHandler() *CarbonCertificateHandler {
	return &CarbonCertificateHandler{}
}

// ---------- Seller: register & attach certificates ----------

type createCertificateRequest struct {
	Registry          string  `json:"registry" binding:"required,max=100"`
	ProjectName       string  `json:"project_name" binding:"required,max=200"`
	ProjectID         string  `json:"project_id" binding:"omitempty,max=100"`
	ProjectType       string  `json:"project_type" binding:"omitempty,max=50"`
	VintageYear       int     `json:"vintage_year" binding:"required,gte=1990,lte=2100"`
	SerialNumberRange string  `json:"serial_number_range" binding:"omitempty,max=200"`
	TotalQuantity     float64 `json:"total_quantity" binding:"required,gt=0"`
}

// CreateCertificate registers a batch of registry-issued carbon credits a
// seller owns, before it's attached to a Listing. Requires an approved
// seller profile, same as CreateListing.
// POST /api/v1/marketplace/carbon-certificates
func (h *CarbonCertificateHandler) CreateCertificate(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var seller models.Seller
	if err := database.DB.Where("user_id = ? AND status = ?", userID, models.SellerStatusApproved).First(&seller).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusForbidden, "you need an approved seller profile to register a carbon credit certificate", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to check seller profile", err)
		return
	}

	var req createCertificateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	cert := models.CarbonCreditCertificate{
		SellerID:          seller.ID,
		Registry:          req.Registry,
		ProjectName:       req.ProjectName,
		ProjectID:         req.ProjectID,
		ProjectType:       req.ProjectType,
		VintageYear:       req.VintageYear,
		SerialNumberRange: req.SerialNumberRange,
		TotalQuantity:     req.TotalQuantity,
		RemainingQuantity: req.TotalQuantity,
		Status:            models.CertificateStatusActive,
	}
	if err := database.DB.Create(&cert).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to create certificate", err)
		return
	}

	utils.Success(c, http.StatusCreated, "carbon credit certificate created", cert)
}

type attachListingRequest struct {
	ListingID uuid.UUID `json:"listing_id" binding:"required"`
}

// AttachToListing links a certificate to the Listing it backs -- one
// certificate per listing, kept intentionally simple so retirement can
// trace a straight line from a buyer's purchase back to a specific
// registry-issued batch. A seller wanting to sell a certificate's credits
// across multiple listings should register separate certificates for each
// serial sub-range instead (which real registries support).
// PUT /api/v1/marketplace/carbon-certificates/:id/attach-listing
func (h *CarbonCertificateHandler) AttachToListing(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	certID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid certificate id", err)
		return
	}

	var req attachListingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	var seller models.Seller
	if err := database.DB.Where("user_id = ?", userID).First(&seller).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusForbidden, "you don't have a seller profile", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to check seller profile", err)
		return
	}

	txErr := database.DB.Transaction(func(tx *gorm.DB) error {
		var cert models.CarbonCreditCertificate
		if err := tx.First(&cert, "id = ? AND seller_id = ?", certID, seller.ID).Error; err != nil {
			return err
		}
		if cert.ListingID != nil {
			return errCertAlreadyAttached
		}

		var listing models.Listing
		if err := tx.First(&listing, "id = ? AND seller_id = ?", req.ListingID, seller.ID).Error; err != nil {
			return err
		}
		if listing.CommodityType != models.CommodityCarbonCredit {
			return errCertListingCommodityWrong
		}

		return tx.Model(&cert).Update("listing_id", listing.ID).Error
	})

	if txErr != nil {
		switch {
		case errors.Is(txErr, gorm.ErrRecordNotFound):
			utils.Fail(c, http.StatusNotFound, "certificate or listing not found, or not yours", txErr)
		case errors.Is(txErr, errCertAlreadyAttached):
			utils.Fail(c, http.StatusConflict, "this certificate is already attached to a listing", nil)
		case errors.Is(txErr, errCertListingCommodityWrong):
			utils.Fail(c, http.StatusBadRequest, "listing must be a carbon_credit listing", nil)
		default:
			utils.Fail(c, http.StatusInternalServerError, "failed to attach certificate", txErr)
		}
		return
	}

	utils.Success(c, http.StatusOK, "certificate attached to listing", nil)
}

// ---------- Viewing ----------

// GetCertificate returns certificate details to any authenticated user,
// not just its owner -- transparency about what backs a carbon credit
// listing (registry, project, vintage, serial range) is standard practice
// in carbon markets, and a buyer evaluating a listing needs to see it.
// GET /api/v1/marketplace/carbon-certificates/:id
func (h *CarbonCertificateHandler) GetCertificate(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid certificate id", err)
		return
	}

	var cert models.CarbonCreditCertificate
	if err := database.DB.First(&cert, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "certificate not found", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch certificate", err)
		return
	}

	utils.Success(c, http.StatusOK, "certificate fetched", cert)
}

// GetMyCertificates returns the authenticated user's own certificates (as
// a seller).
// GET /api/v1/marketplace/my-carbon-certificates
func (h *CarbonCertificateHandler) GetMyCertificates(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var seller models.Seller
	if err := database.DB.Where("user_id = ?", userID).First(&seller).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Success(c, http.StatusOK, "no certificates", []models.CarbonCreditCertificate{})
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to load seller profile", err)
		return
	}

	var certs []models.CarbonCreditCertificate
	if err := database.DB.Where("seller_id = ?", seller.ID).Order("created_at DESC").Find(&certs).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch your certificates", err)
		return
	}

	utils.Success(c, http.StatusOK, "your certificates fetched", certs)
}

// ---------- Retirement ----------

type retireCreditsRequest struct {
	Quantity         float64 `json:"quantity" binding:"required,gt=0"`
	BeneficiaryName  string  `json:"beneficiary_name" binding:"omitempty,max=200"`
	RetirementReason string  `json:"retirement_reason" binding:"omitempty,max=500"`
}

// generateRetirementReference produces a locally-unique display reference
// for a retirement -- NOT a real registry retirement certificate number.
// A real registry integration would use the registry's own reference
// instead of this.
func generateRetirementReference(certID uuid.UUID) string {
	short := strings.ToUpper(strings.ReplaceAll(certID.String(), "-", "")[:8])
	return fmt.Sprintf("RET-%s-%d", short, time.Now().UnixNano()%1_000_000)
}

// RetireCredits permanently claims (retires) a quantity of credits from a
// certificate. The caller can only retire credits they've actually
// purchased and had delivered (checked by summing their delivered Orders
// against the certificate's Listing) minus whatever they've already
// retired from this certificate -- so a buyer can never retire more than
// they bought, and can never retire someone else's purchase. This whole
// operation runs in one transaction: the retirement record and the
// certificate's remaining-quantity decrement either both happen or
// neither does.
// POST /api/v1/marketplace/carbon-certificates/:id/retire
func (h *CarbonCertificateHandler) RetireCredits(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	certID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid certificate id", err)
		return
	}

	var req retireCreditsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	var retirement models.CreditRetirement
	txErr := database.DB.Transaction(func(tx *gorm.DB) error {
		var cert models.CarbonCreditCertificate
		if err := tx.First(&cert, "id = ?", certID).Error; err != nil {
			return err
		}
		if cert.ListingID == nil {
			return errCertConflict
		}
		if req.Quantity > cert.RemainingQuantity {
			return errCertInsufficientRemaining
		}

		var purchased float64
		if err := tx.Model(&models.Order{}).
			Where("listing_id = ? AND buyer_id = ? AND status = ?", *cert.ListingID, userID, models.OrderStatusDelivered).
			Select("COALESCE(SUM(quantity), 0)").Scan(&purchased).Error; err != nil {
			return err
		}

		var alreadyRetired float64
		if err := tx.Model(&models.CreditRetirement{}).
			Where("certificate_id = ? AND retired_by_user_id = ?", certID, userID).
			Select("COALESCE(SUM(quantity), 0)").Scan(&alreadyRetired).Error; err != nil {
			return err
		}

		available := purchased - alreadyRetired
		if req.Quantity > available {
			return errCertInsufficientPurchased
		}

		retirement = models.CreditRetirement{
			CertificateID:    certID,
			RetiredByUserID:  userID,
			Quantity:         req.Quantity,
			BeneficiaryName:  req.BeneficiaryName,
			RetirementReason: req.RetirementReason,
			ReferenceNumber:  generateRetirementReference(certID),
		}
		if err := tx.Create(&retirement).Error; err != nil {
			return err
		}

		remaining := cert.RemainingQuantity - req.Quantity
		updates := map[string]interface{}{"remaining_quantity": remaining}
		if remaining <= 0 {
			updates["status"] = models.CertificateStatusFullyRetired
		}
		return tx.Model(&cert).Updates(updates).Error
	})

	if txErr != nil {
		switch {
		case errors.Is(txErr, gorm.ErrRecordNotFound):
			utils.Fail(c, http.StatusNotFound, "certificate not found", txErr)
		case errors.Is(txErr, errCertConflict):
			utils.Fail(c, http.StatusConflict, "this certificate isn't attached to a listing yet", nil)
		case errors.Is(txErr, errCertInsufficientRemaining):
			utils.Fail(c, http.StatusConflict, "not enough remaining credits on this certificate", nil)
		case errors.Is(txErr, errCertInsufficientPurchased):
			utils.Fail(c, http.StatusForbidden, "you can only retire credits you've purchased (and had delivered) and haven't already retired", nil)
		default:
			utils.Fail(c, http.StatusInternalServerError, "failed to retire credits", txErr)
		}
		return
	}

	utils.Success(c, http.StatusCreated, "credits retired", retirement)
}

// GetMyRetirements returns every retirement the authenticated user has
// made.
// GET /api/v1/marketplace/my-retirements
func (h *CarbonCertificateHandler) GetMyRetirements(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var retirements []models.CreditRetirement
	if err := database.DB.Where("retired_by_user_id = ?", userID).Order("created_at DESC").Find(&retirements).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch your retirements", err)
		return
	}

	utils.Success(c, http.StatusOK, "your retirements fetched", retirements)
}

// GetRetirementsForCertificate returns every retirement recorded against a
// certificate, visible to any authenticated user -- same transparency
// reasoning as GetCertificate: anyone should be able to verify how much of
// a certificate has already been claimed.
// GET /api/v1/marketplace/carbon-certificates/:id/retirements
func (h *CarbonCertificateHandler) GetRetirementsForCertificate(c *gin.Context) {
	certID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid certificate id", err)
		return
	}

	var retirements []models.CreditRetirement
	if err := database.DB.Where("certificate_id = ?", certID).Order("created_at DESC").Find(&retirements).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch retirements", err)
		return
	}

	utils.Success(c, http.StatusOK, "retirements fetched", retirements)
}

// ---------- Admin visibility ----------

// ListAllCertificatesAdmin returns every certificate regardless of status,
// for admin oversight -- mirrors the other ListAll*Admin handlers.
// GET /api/v1/marketplace/admin/carbon-certificates
func (h *CarbonCertificateHandler) ListAllCertificatesAdmin(c *gin.Context) {
	page, limit, offset := utils.ParsePageLimit(c, 20, 100)

	var total int64
	if err := database.DB.Model(&models.CarbonCreditCertificate{}).Count(&total).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count certificates", err)
		return
	}

	var certs []models.CarbonCreditCertificate
	if err := database.DB.Order("created_at DESC").Limit(limit).Offset(offset).Find(&certs).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch certificates", err)
		return
	}

	utils.Success(c, http.StatusOK, "certificates fetched", gin.H{
		"certificates": certs,
		"page":         page,
		"limit":        limit,
		"total":        total,
	})
}
