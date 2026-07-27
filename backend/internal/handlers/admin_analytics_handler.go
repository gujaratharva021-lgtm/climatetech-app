package handlers

import (
	"net/http"
	"time"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type AdminAnalyticsHandler struct{}

func NewAdminAnalyticsHandler() *AdminAnalyticsHandler {
	return &AdminAnalyticsHandler{}
}

type carbonCategoryBreakdown struct {
	Category string  `json:"category"`
	CO2Kg    float64 `json:"co2_kg"`
}

// GetCarbonOverview returns platform-wide carbon tracking stats. Every
// number here comes from a DB aggregate (SUM/GROUP BY/COUNT/COUNT DISTINCT)
// — never a full-table load into Go, regardless of how many activities exist.
// GET /api/v1/admin/carbon-overview
func (h *AdminAnalyticsHandler) GetCarbonOverview(c *gin.Context) {
	var totalCO2 float64
	if err := database.DB.Model(&models.CarbonActivity{}).
		Select("COALESCE(SUM(co2_kg), 0)").
		Scan(&totalCO2).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute total CO2", err)
		return
	}

	var breakdown []carbonCategoryBreakdown
	if err := database.DB.Model(&models.CarbonActivity{}).
		Select("category, COALESCE(SUM(co2_kg), 0) as co2_kg").
		Group("category").
		Scan(&breakdown).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute category breakdown", err)
		return
	}

	var totalEntries int64
	if err := database.DB.Model(&models.CarbonActivity{}).Count(&totalEntries).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count log entries", err)
		return
	}

	var activeUserCount int64
	if err := database.DB.Model(&models.CarbonActivity{}).
		Distinct("user_id").
		Count(&activeUserCount).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count active users", err)
		return
	}

	utils.Success(c, http.StatusOK, "carbon overview fetched", gin.H{
		"total_co2_kg":       totalCO2,
		"category_breakdown": breakdown,
		"total_log_entries":  totalEntries,
		"active_user_count":  activeUserCount,
	})
}

type roleCount struct {
	Role  string `json:"role"`
	Count int64  `json:"count"`
}

type kycStatusCount struct {
	KYCStatus string `json:"kyc_status"`
	Count     int64  `json:"count"`
}

// GetPlatformOverview returns platform-wide user stats: totals, signups
// this week/month, breakdown by role, and breakdown by KYC status.
// GET /api/v1/admin/analytics/platform-overview
func (h *AdminAnalyticsHandler) GetPlatformOverview(c *gin.Context) {
	var totalUsers int64
	if err := database.DB.Model(&models.User{}).Count(&totalUsers).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count users", err)
		return
	}

	var newThisWeek int64
	if err := database.DB.Model(&models.User{}).
		Where("created_at >= ?", time.Now().AddDate(0, 0, -7)).
		Count(&newThisWeek).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count new users this week", err)
		return
	}

	var newThisMonth int64
	if err := database.DB.Model(&models.User{}).
		Where("created_at >= ?", time.Now().AddDate(0, -1, 0)).
		Count(&newThisMonth).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count new users this month", err)
		return
	}

	roleBreakdown := []roleCount{}
	if err := database.DB.Model(&models.User{}).
		Select("role, COUNT(*) as count").
		Group("role").
		Scan(&roleBreakdown).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute role breakdown", err)
		return
	}

	kycBreakdown := []kycStatusCount{}
	if err := database.DB.Model(&models.User{}).
		Select("kyc_status, COUNT(*) as count").
		Group("kyc_status").
		Scan(&kycBreakdown).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute KYC breakdown", err)
		return
	}

	utils.Success(c, http.StatusOK, "platform overview fetched", gin.H{
		"total_users":    totalUsers,
		"new_this_week":  newThisWeek,
		"new_this_month": newThisMonth,
		"role_breakdown": roleBreakdown,
		"kyc_breakdown":  kycBreakdown,
	})
}

type orderStatusCount struct {
	Status string  `json:"status"`
	Count  int64   `json:"count"`
	Amount float64 `json:"amount"`
}

// GetMarketplaceOverview returns platform-wide marketplace stats: listing
// counts, order counts/GMV broken down by status, and RFQ/bid volume.
// GET /api/v1/admin/analytics/marketplace-overview
func (h *AdminAnalyticsHandler) GetMarketplaceOverview(c *gin.Context) {
	var totalListings int64
	if err := database.DB.Model(&models.Listing{}).Count(&totalListings).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count listings", err)
		return
	}

	var activeListings int64
	if err := database.DB.Model(&models.Listing{}).
		Where("is_active = ?", true).
		Count(&activeListings).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count active listings", err)
		return
	}

	var totalOrders int64
	if err := database.DB.Model(&models.Order{}).Count(&totalOrders).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count orders", err)
		return
	}

	var totalGMV float64
	if err := database.DB.Model(&models.Order{}).
		Where("status != ?", "cancelled").
		Select("COALESCE(SUM(total_amount), 0)").
		Scan(&totalGMV).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute GMV", err)
		return
	}

	ordersByStatus := []orderStatusCount{}
	if err := database.DB.Model(&models.Order{}).
		Select("status, COUNT(*) as count, COALESCE(SUM(total_amount), 0) as amount").
		Group("status").
		Scan(&ordersByStatus).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute order status breakdown", err)
		return
	}

	var totalRFQs int64
	if err := database.DB.Model(&models.RFQ{}).Count(&totalRFQs).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count RFQs", err)
		return
	}

	var totalBids int64
	if err := database.DB.Model(&models.Bid{}).Count(&totalBids).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count bids", err)
		return
	}

	utils.Success(c, http.StatusOK, "marketplace overview fetched", gin.H{
		"total_listings":   totalListings,
		"active_listings":  activeListings,
		"total_orders":     totalOrders,
		"total_gmv":        totalGMV,
		"orders_by_status": ordersByStatus,
		"total_rfqs":       totalRFQs,
		"total_bids":       totalBids,
	})
}

type vehicleStatusCount struct {
	Status string `json:"status"`
	Count  int64  `json:"count"`
}

type bookingStatusCount struct {
	Status string `json:"status"`
	Count  int64  `json:"count"`
}

// GetLogisticsOverview returns platform-wide logistics stats: vehicle and
// booking counts broken down by status.
// GET /api/v1/admin/analytics/logistics-overview
func (h *AdminAnalyticsHandler) GetLogisticsOverview(c *gin.Context) {
	var totalVehicles int64
	if err := database.DB.Model(&models.Vehicle{}).Count(&totalVehicles).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count vehicles", err)
		return
	}

	vehiclesByStatus := []vehicleStatusCount{}
	if err := database.DB.Model(&models.Vehicle{}).
		Select("status, COUNT(*) as count").
		Group("status").
		Scan(&vehiclesByStatus).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute vehicle status breakdown", err)
		return
	}

	var totalBookings int64
	if err := database.DB.Model(&models.Booking{}).Count(&totalBookings).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count bookings", err)
		return
	}

	bookingsByStatus := []bookingStatusCount{}
	if err := database.DB.Model(&models.Booking{}).
		Select("status, COUNT(*) as count").
		Group("status").
		Scan(&bookingsByStatus).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute booking status breakdown", err)
		return
	}

	utils.Success(c, http.StatusOK, "logistics overview fetched", gin.H{
		"total_vehicles":     totalVehicles,
		"vehicles_by_status": vehiclesByStatus,
		"total_bookings":     totalBookings,
		"bookings_by_status": bookingsByStatus,
	})
}

type dailyOrderCount struct {
	Day    string  `json:"day"`
	Count  int64   `json:"count"`
	Amount float64 `json:"amount"`
}

// GetOrderTrends returns daily order counts and total value for the last
// 30 days, oldest first, for rendering a trend chart. Days with zero
// orders are simply absent rather than zero-filled.
// GET /api/v1/admin/analytics/order-trends
func (h *AdminAnalyticsHandler) GetOrderTrends(c *gin.Context) {
	trends := []dailyOrderCount{}
	if err := database.DB.Model(&models.Order{}).
		Select("TO_CHAR(created_at, 'YYYY-MM-DD') as day, COUNT(*) as count, COALESCE(SUM(total_amount), 0) as amount").
		Where("created_at >= ?", time.Now().AddDate(0, 0, -30)).
		Group("day").
		Order("day ASC").
		Scan(&trends).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute order trends", err)
		return
	}

	utils.Success(c, http.StatusOK, "order trends fetched", gin.H{
		"trends": trends,
	})
}
