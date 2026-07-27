package routes

import (
	"context"
	"net/http"
	"time"

	"climatetech-backend/internal/config"
	"climatetech-backend/internal/database"
	"climatetech-backend/internal/handlers"
	"climatetech-backend/internal/middleware"
	"climatetech-backend/internal/services"

	"github.com/gin-gonic/gin"
)

// healthCheckHandler pings Postgres and Redis with a short timeout and
// reports 503 if either is unreachable, so an ALB/ECS health check actually
// reflects whether this instance can serve real traffic.
func healthCheckHandler(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
	defer cancel()

	sqlDB, err := database.DB.DB()
	if err != nil || sqlDB.PingContext(ctx) != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"status": "degraded", "service": "climatetech-backend", "database": "down"})
		return
	}

	if err := database.RedisClient.Ping(ctx).Err(); err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"status": "degraded", "service": "climatetech-backend", "redis": "down"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "climatetech-backend"})
}

func RegisterRoutes(router *gin.Engine, cfg *config.Config) {
	authHandler := handlers.NewAuthHandler(cfg)
	userHandler := handlers.NewUserHandler()

	weatherService := services.NewWeatherService(cfg.OpenWeatherAPIKey)
	geminiService := services.NewGeminiService(cfg.GeminiAPIKey, cfg.GeminiModel)
	fcmService := services.NewFCMService(cfg.FirebaseCredentialsPath)
	newsService := services.NewNewsService(cfg.NewsAPIKey)

	climateHandler := handlers.NewClimateHandler(weatherService, geminiService, fcmService)
	carbonHandler := handlers.NewCarbonHandler()
	insightsHandler := handlers.NewInsightsHandler(geminiService)
	alertHandler := handlers.NewAlertHandler()
	marketplaceHandler := handlers.NewMarketplaceHandler()
	rfqHandler := handlers.NewRFQHandler()
	orderHandler := handlers.NewOrderHandler()
	razorpayService := services.NewRazorpayService(cfg.RazorpayKeyID, cfg.RazorpayKeySecret)
	paymentHandler := handlers.NewPaymentHandler(razorpayService, cfg.RazorpayWebhookSecret, cfg.RazorpayKeyID)
	shipmentHandler := handlers.NewShipmentHandler()
	priceIndexService := services.NewPriceIndexService(database.DB, database.RedisClient)
	priceIndexHandler := handlers.NewPriceIndexHandler(priceIndexService)
	aiHandler := handlers.NewAIHandler(geminiService, priceIndexService)
	financingHandler := handlers.NewFinancingHandler()
	inspectionHandler := handlers.NewInspectionHandler()
	carbonCertHandler := handlers.NewCarbonCertificateHandler()
	newsHandler := handlers.NewNewsHandler(newsService)
	challengeHandler := handlers.NewChallengeHandler(geminiService)
	reportHandler := handlers.NewReportHandler()
	adminUserHandler := handlers.NewAdminUserHandler()
	adminNewsHandler := handlers.NewAdminNewsHandler()
	adminNotificationHandler := handlers.NewAdminNotificationHandler(fcmService)
	adminAnalyticsHandler := handlers.NewAdminAnalyticsHandler()
	kycHandler := handlers.NewKYCHandler()
	logisticsHandler := handlers.NewLogisticsHandler()

	// /health verifies the app's actual dependencies (Postgres, Redis), not
	// just that the process is running — a static 200 would let an
	// ALB/ECS health check keep routing traffic to an instance whose DB or
	// cache connection has died. Used as both the ALB target-group health
	// check and the Docker HEALTHCHECK.
	router.GET("/health", healthCheckHandler)
	router.POST("/webhooks/razorpay", paymentHandler.RazorpayWebhook)

	v1 := router.Group("/api/v1")
	{
		auth := v1.Group("/auth")
		{
			// Rate-limited by client IP — these are the endpoints an
			// unauthenticated attacker can hit repeatedly to brute-force
			// credentials or hammer the DB with account-creation attempts.
			auth.POST("/register", middleware.RateLimit("register", 10, time.Minute), authHandler.Register)
			auth.POST("/login", middleware.RateLimit("login", 10, time.Minute), authHandler.Login)
			auth.POST("/refresh", middleware.RateLimit("refresh", 20, time.Minute), authHandler.RefreshToken)
			auth.POST("/logout", middleware.AuthRequired(cfg), authHandler.Logout)
		}

		users := v1.Group("/users")
		users.Use(middleware.AuthRequired(cfg))
		{
			users.GET("/profile", userHandler.GetProfile)
			users.PUT("/profile", userHandler.UpdateProfile)
			users.PUT("/change-password", middleware.RateLimit("change-password", 10, time.Minute), userHandler.ChangePassword)
			users.PUT("/fcm-token", userHandler.UpdateFCMToken)
		}

		kyc := v1.Group("/kyc")
		kyc.Use(middleware.AuthRequired(cfg))
		{
			kyc.POST("/submit", middleware.RateLimit("kyc-submit", 10, time.Minute), kycHandler.SubmitKYC)
			kyc.GET("/me", kycHandler.GetMyKYC)
		}

		logistics := v1.Group("/logistics")
		logistics.Use(middleware.AuthRequired(cfg))
		{
			logistics.POST("/vehicles", logisticsHandler.CreateVehicle)
			logistics.GET("/vehicles", logisticsHandler.BrowseVehicles)
			logistics.GET("/vehicles/:id", logisticsHandler.GetVehicle)
			logistics.PUT("/vehicles/:id", logisticsHandler.UpdateVehicle)
			logistics.DELETE("/vehicles/:id", logisticsHandler.DeleteVehicle)
			logistics.GET("/my-vehicles", logisticsHandler.GetMyVehicles)

			logistics.POST("/bookings", logisticsHandler.CreateBooking)
			logistics.GET("/bookings/:id", logisticsHandler.GetBooking)
			logistics.PUT("/bookings/:id/status", logisticsHandler.UpdateBookingStatus)
			logistics.GET("/my-bookings", logisticsHandler.GetMyBookings)
		}

		climate := v1.Group("/climate")
		climate.Use(middleware.AuthRequired(cfg))
		{
			climate.GET("/current", climateHandler.GetCurrentClimate)
			climate.GET("/history", climateHandler.GetClimateHistory)
			climate.GET("/forecast", climateHandler.GetForecast)
			climate.GET("/ai-summary", climateHandler.GetWeatherSummary)
		}

		carbon := v1.Group("/carbon")
		carbon.Use(middleware.AuthRequired(cfg))
		{
			carbon.POST("/log", carbonHandler.LogActivity)
			carbon.GET("/history", carbonHandler.GetHistory)
			carbon.GET("/summary", carbonHandler.GetSummary)
			carbon.GET("/daily", carbonHandler.GetDailyBreakdown)
			carbon.GET("/options", carbonHandler.GetOptions)
		}

		insights := v1.Group("/insights")
		insights.Use(middleware.AuthRequired(cfg))
		{
			insights.GET("", insightsHandler.GetInsights)
		}

		alerts := v1.Group("/alerts")
		alerts.Use(middleware.AuthRequired(cfg))
		{
			alerts.GET("/history", alertHandler.GetHistory)
			alerts.GET("/unread-count", alertHandler.GetUnreadCount)
			alerts.PUT("/:id/read", alertHandler.MarkAsRead)
		}

		marketplace := v1.Group("/marketplace")
		marketplace.Use(middleware.AuthRequired(cfg))
		{
			marketplace.POST("/seller/apply", marketplaceHandler.ApplySeller)
			marketplace.GET("/seller/me", marketplaceHandler.GetMySellerProfile)

			marketplace.GET("/listings", marketplaceHandler.BrowseListings)
			marketplace.GET("/listings/:id", marketplaceHandler.GetListingDetail)
			marketplace.POST("/listings", marketplaceHandler.CreateListing)
			marketplace.DELETE("/listings/:id", marketplaceHandler.DeleteListing)
			marketplace.GET("/my-listings", marketplaceHandler.GetMyListings)

			marketplace.POST("/rfq", rfqHandler.CreateRFQ)
			marketplace.GET("/rfq", rfqHandler.BrowseRFQs)
			marketplace.GET("/rfq/:id", rfqHandler.GetRFQDetail)
			marketplace.PUT("/rfq/:id/cancel", rfqHandler.CancelRFQ)
			marketplace.POST("/rfq/:id/bids", rfqHandler.SubmitBid)
			marketplace.GET("/rfq/:id/bids", rfqHandler.ListBidsForRFQ)
			marketplace.PUT("/rfq/:id/bids/:bid_id/accept", rfqHandler.AcceptBid)
			marketplace.GET("/my-rfqs", rfqHandler.GetMyRFQs)
			marketplace.GET("/my-bids", rfqHandler.GetMyBids)

			marketplace.POST("/rfq/:id/order", orderHandler.CreateOrderFromRFQ)
			marketplace.POST("/listings/:id/order", orderHandler.CreateOrderFromListing)
			marketplace.GET("/orders/:id", orderHandler.GetOrderDetail)
			marketplace.PUT("/orders/:id/confirm", orderHandler.ConfirmOrder)
			marketplace.PUT("/orders/:id/ship", orderHandler.ShipOrder)
			marketplace.PUT("/orders/:id/deliver", orderHandler.DeliverOrder)
			marketplace.PUT("/orders/:id/cancel", orderHandler.CancelOrder)
			marketplace.GET("/my-orders", orderHandler.GetMyOrdersAsBuyer)
			marketplace.GET("/seller/orders", orderHandler.GetMySellerOrders)

			marketplace.POST("/orders/:id/payment/create", paymentHandler.CreatePaymentOrder)
			marketplace.POST("/orders/:id/payment/verify", paymentHandler.VerifyPayment)
			marketplace.GET("/orders/:id/payment", paymentHandler.GetPaymentStatus)

			marketplace.POST("/orders/:id/shipment", shipmentHandler.CreateShipment)
			marketplace.PUT("/shipments/:id/status", shipmentHandler.UpdateShipmentStatus)
			marketplace.GET("/orders/:id/shipment", shipmentHandler.GetShipmentByOrder)

			marketplace.GET("/price-index", priceIndexHandler.GetAllPriceIndexes)
			marketplace.GET("/price-index/:commodity_type", priceIndexHandler.GetPriceIndex)
			marketplace.GET("/price-index/:commodity_type/history", priceIndexHandler.GetPriceHistory)

			marketplace.POST("/orders/:id/ai/draft-contract", middleware.RateLimit("ai", 20, time.Minute), aiHandler.DraftContract)

			ai := marketplace.Group("/ai")
			ai.Use(middleware.RateLimit("ai", 20, time.Minute))
			{
				ai.POST("/chat", aiHandler.Chat)
				ai.GET("/market-insights/:commodity_type", aiHandler.GetMarketInsights)
				ai.POST("/recommend-listings", aiHandler.RecommendListings)
			}

			marketplace.POST("/orders/:id/financing", financingHandler.CreateFinancingRequest)
			marketplace.GET("/financing/:id", financingHandler.GetFinancingRequest)
			marketplace.GET("/my-financing", financingHandler.GetMyFinancingRequests)
			marketplace.GET("/orders/:id/financing", financingHandler.GetFinancingForOrder)

			marketplace.POST("/orders/:id/inspection", inspectionHandler.CreateInspectionRequest)
			marketplace.GET("/inspections/:id", inspectionHandler.GetInspectionRequest)
			marketplace.PUT("/inspections/:id/schedule", inspectionHandler.ScheduleInspection)
			marketplace.PUT("/inspections/:id/complete", inspectionHandler.CompleteInspection)
			marketplace.PUT("/inspections/:id/cancel", inspectionHandler.CancelInspection)
			marketplace.GET("/my-inspections", inspectionHandler.GetMyInspections)
			marketplace.GET("/inspector/assigned", inspectionHandler.GetAssignedInspections)

			marketplace.POST("/carbon-certificates", carbonCertHandler.CreateCertificate)
			marketplace.PUT("/carbon-certificates/:id/attach-listing", carbonCertHandler.AttachToListing)
			marketplace.GET("/carbon-certificates/:id", carbonCertHandler.GetCertificate)
			marketplace.POST("/carbon-certificates/:id/retire", carbonCertHandler.RetireCredits)
			marketplace.GET("/carbon-certificates/:id/retirements", carbonCertHandler.GetRetirementsForCertificate)
			marketplace.GET("/my-carbon-certificates", carbonCertHandler.GetMyCertificates)
			marketplace.GET("/my-retirements", carbonCertHandler.GetMyRetirements)

			marketplaceAdmin := marketplace.Group("/admin")
			marketplaceAdmin.Use(middleware.RequireRole("admin"))
			{
				marketplaceAdmin.GET("/sellers", marketplaceHandler.ListSellersByStatus)
				marketplaceAdmin.PUT("/sellers/:id/approve", marketplaceHandler.ApproveSeller)
				marketplaceAdmin.PUT("/sellers/:id/reject", marketplaceHandler.RejectSeller)
				marketplaceAdmin.GET("/listings", marketplaceHandler.ListAllListingsAdmin)
				marketplaceAdmin.POST("/listings", marketplaceHandler.AdminCreateListing)
				marketplaceAdmin.PUT("/listings/:id", marketplaceHandler.UpdateListingAdmin)
				marketplaceAdmin.DELETE("/listings/:id", marketplaceHandler.DeleteListingAdmin)
				marketplaceAdmin.GET("/rfqs", rfqHandler.ListAllRFQsAdmin)
				marketplaceAdmin.GET("/orders", orderHandler.ListAllOrdersAdmin)
				marketplaceAdmin.PUT("/orders/:id/release-escrow", paymentHandler.ReleaseEscrow)
				marketplaceAdmin.POST("/orders/:id/refund", paymentHandler.RefundPayment)
				marketplaceAdmin.GET("/shipments", shipmentHandler.ListAllShipmentsAdmin)
				marketplaceAdmin.POST("/price-index/snapshot", priceIndexHandler.RecordSnapshotAdmin)
				marketplaceAdmin.GET("/financing", financingHandler.ListAllFinancingAdmin)
				marketplaceAdmin.PUT("/financing/:id", financingHandler.UpdateFinancingStatusAdmin)
				marketplaceAdmin.GET("/inspections", inspectionHandler.ListAllInspectionsAdmin)
				marketplaceAdmin.PUT("/inspections/:id/assign", inspectionHandler.AssignInspectorAdmin)
				marketplaceAdmin.GET("/carbon-certificates", carbonCertHandler.ListAllCertificatesAdmin)
			}
		}

		news := v1.Group("/news")
		news.Use(middleware.AuthRequired(cfg))
		{
			news.GET("", newsHandler.GetNews)
		}

		challenges := v1.Group("/challenges")
		challenges.Use(middleware.AuthRequired(cfg))
		{
			challenges.GET("", challengeHandler.GetChallenges)
			challenges.GET("/new-count", challengeHandler.GetNewChallengesCount)
			challenges.POST("/:id/join", challengeHandler.JoinChallenge)
			challenges.POST("/:id/checkin", challengeHandler.CheckIn)
		}

		leaderboard := v1.Group("/leaderboard")
		leaderboard.Use(middleware.AuthRequired(cfg))
		{
			leaderboard.GET("", challengeHandler.GetLeaderboard)
		}

		reports := v1.Group("/reports")
		reports.Use(middleware.AuthRequired(cfg))
		{
			reports.GET("/generate", reportHandler.GenerateReport)
		}

		admin := v1.Group("/admin")
		admin.Use(middleware.AuthRequired(cfg), middleware.RequireRole("admin"))
		{
			admin.GET("/ping", func(c *gin.Context) {
				c.JSON(http.StatusOK, gin.H{"message": "admin access confirmed"})
			})

			admin.GET("/users", adminUserHandler.ListUsers)
			admin.PUT("/users/:id/role", adminUserHandler.UpdateUserRole)
			admin.PUT("/users/:id/status", adminUserHandler.UpdateUserStatus)

			admin.POST("/challenges", challengeHandler.CreateChallengeAdmin)
			admin.PUT("/challenges/:id", challengeHandler.UpdateChallengeAdmin)
			admin.DELETE("/challenges/:id", challengeHandler.DeleteChallengeAdmin)

			admin.DELETE("/news", adminNewsHandler.HideArticle)

			admin.POST("/notifications/broadcast", adminNotificationHandler.Broadcast)

			admin.GET("/carbon-overview", adminAnalyticsHandler.GetCarbonOverview)

			admin.GET("/analytics/platform-overview", adminAnalyticsHandler.GetPlatformOverview)
			admin.GET("/analytics/marketplace-overview", adminAnalyticsHandler.GetMarketplaceOverview)
			admin.GET("/analytics/logistics-overview", adminAnalyticsHandler.GetLogisticsOverview)
			admin.GET("/analytics/order-trends", adminAnalyticsHandler.GetOrderTrends)

			admin.GET("/kyc/pending", kycHandler.ListPendingKYC)
			admin.PUT("/kyc/:id/approve", kycHandler.ApproveKYC)
			admin.PUT("/kyc/:id/reject", kycHandler.RejectKYC)
		}
	}
}
