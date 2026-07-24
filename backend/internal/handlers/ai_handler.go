package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/services"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// aiDraftDisclaimer is returned as its own field (not just baked into the
// generated text) so the frontend can't accidentally drop it -- an
// AI-drafted contract needs this caveat attached every time, not only when
// the model happens to remember to add it itself.
const aiDraftDisclaimer = "This is an AI-generated draft for discussion purposes only. It is not legal advice and should be reviewed by a qualified lawyer before being used as a binding agreement."

type AIHandler struct {
	gemini     *services.GeminiService
	priceIndex *services.PriceIndexService
}

func NewAIHandler(gemini *services.GeminiService, priceIndex *services.PriceIndexService) *AIHandler {
	return &AIHandler{gemini: gemini, priceIndex: priceIndex}
}

// ---------- Chat Assistant ----------

type chatMessage struct {
	Role    string `json:"role" binding:"required,oneof=user assistant"`
	Content string `json:"content" binding:"required,max=4000"`
}

type chatRequest struct {
	Message string        `json:"message" binding:"required,max=2000"`
	History []chatMessage `json:"history" binding:"omitempty,max=20,dive"`
}

// Chat is a general-purpose trade assistant: answers questions about how
// the marketplace works and general energy-commodity trading concepts.
// History is client-maintained (sent back on every call) rather than
// stored server-side -- keeps this endpoint stateless instead of needing a
// whole conversation-storage feature just for chat. Capped at 20 prior
// turns so a long-running client session can't blow up prompt size/cost.
// POST /api/v1/marketplace/ai/chat
func (h *AIHandler) Chat(c *gin.Context) {
	var req chatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	var transcript strings.Builder
	transcript.WriteString("You are a helpful, concise trade assistant for a B2B energy commodity marketplace (coal, biomass, coke, carbon credits). ")
	transcript.WriteString("Answer questions about how the platform works (listings, RFQs, reverse auctions, orders, escrow payments, shipments) and general energy commodity trading concepts. ")
	transcript.WriteString("You do not have access to any specific user's private data, live prices, or account details beyond what's given to you in this conversation -- if asked about those, say so plainly and suggest checking the relevant page in the app instead of guessing. ")
	transcript.WriteString("Keep replies short and practical.\n\n")

	for _, m := range req.History {
		label := "User"
		if m.Role == "assistant" {
			label = "Assistant"
		}
		transcript.WriteString(label + ": " + m.Content + "\n")
	}
	transcript.WriteString("User: " + req.Message + "\nAssistant:")

	reply, err := h.gemini.GenerateInsights(transcript.String())
	if err != nil {
		utils.Fail(c, http.StatusBadGateway, "AI assistant is unavailable right now", err)
		return
	}

	utils.Success(c, http.StatusOK, "reply generated", gin.H{"reply": strings.TrimSpace(reply)})
}

// ---------- Market Insights ----------

type marketInsightsResponse struct {
	CommodityType      string               `json:"commodity_type"`
	ListingBands       []services.PriceBand `json:"listing_bands"`
	TransactedBands    []services.PriceBand `json:"transacted_bands"`
	OpenRFQCount       int64                `json:"open_rfq_count"`
	ActiveListingCount int64                `json:"active_listing_count"`
	Narrative          string               `json:"narrative"`
	GeneratedAt        time.Time            `json:"generated_at"`
}

// GetMarketInsights combines the real live price index (Phase 6) with
// current RFQ/listing counts, and asks Gemini for a short narrative read
// of that data -- explicitly instructed not to invent numbers or phrase
// anything as buy/sell advice (see buildMarketInsightsPrompt). This is a
// qualitative LLM read of recent platform data, not an actual statistical
// forecasting model -- named "insights" rather than "prediction" for that
// reason. Cached for an hour, same TTL as the underlying price index.
// GET /api/v1/marketplace/ai/market-insights/:commodity_type
func (h *AIHandler) GetMarketInsights(c *gin.Context) {
	commodityType := c.Param("commodity_type")
	if !isValidIndexCommodity(commodityType) {
		utils.Fail(c, http.StatusBadRequest, "commodity_type must be one of coal, biomass, coke, carbon_credit", nil)
		return
	}

	cacheKey := "market_insights:" + commodityType
	if cached, err := database.RedisClient.Get(database.Ctx, cacheKey).Result(); err == nil {
		var resp marketInsightsResponse
		if jsonErr := json.Unmarshal([]byte(cached), &resp); jsonErr == nil {
			utils.Success(c, http.StatusOK, "market insights fetched", resp)
			return
		}
	}

	ct := models.CommodityType(commodityType)

	index, err := h.priceIndex.GetLiveIndex(ct)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to compute price index", err)
		return
	}

	var openRFQCount int64
	database.DB.Model(&models.RFQ{}).Where("commodity_type = ? AND status = ?", ct, models.RFQStatusOpen).Count(&openRFQCount)

	var activeListingCount int64
	database.DB.Model(&models.Listing{}).Where("commodity_type = ? AND is_active = ?", ct, true).Count(&activeListingCount)

	narrative, err := h.gemini.GenerateInsights(buildMarketInsightsPrompt(string(ct), index, openRFQCount, activeListingCount))
	if err != nil {
		utils.Fail(c, http.StatusBadGateway, "AI market insights are unavailable right now", err)
		return
	}

	resp := marketInsightsResponse{
		CommodityType:      string(ct),
		ListingBands:       index.ListingBands,
		TransactedBands:    index.TransactedBands,
		OpenRFQCount:       openRFQCount,
		ActiveListingCount: activeListingCount,
		Narrative:          strings.TrimSpace(narrative),
		GeneratedAt:        time.Now(),
	}

	if data, err := json.Marshal(resp); err == nil {
		// Caching is a performance/cost optimization, not a correctness
		// requirement -- a Redis write failure here shouldn't fail the
		// request when the response is already computed.
		database.RedisClient.Set(database.Ctx, cacheKey, data, time.Hour)
	}

	utils.Success(c, http.StatusOK, "market insights fetched", resp)
}

func buildMarketInsightsPrompt(commodityType string, index *services.LiveIndex, openRFQCount, activeListingCount int64) string {
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("You are a market analyst for a B2B energy commodity marketplace. Write a short (3-5 sentence) market insight for %s based ONLY on this real platform data:\n\n", commodityType))

	sb.WriteString("Active listings (current asking prices), by unit:\n")
	if len(index.ListingBands) == 0 {
		sb.WriteString("  (no active listings)\n")
	}
	for _, b := range index.ListingBands {
		sb.WriteString(fmt.Sprintf("  - %d listings at %s: avg %.2f, range %.2f-%.2f\n", b.SampleSize, b.Unit, b.AvgPrice, b.MinPrice, b.MaxPrice))
	}

	sb.WriteString("\nActual transacted prices in the last 30 days, by unit:\n")
	if len(index.TransactedBands) == 0 {
		sb.WriteString("  (no completed trades in this window)\n")
	}
	for _, b := range index.TransactedBands {
		sb.WriteString(fmt.Sprintf("  - %d orders at %s: avg %.2f, range %.2f-%.2f\n", b.SampleSize, b.Unit, b.AvgPrice, b.MinPrice, b.MaxPrice))
	}

	sb.WriteString(fmt.Sprintf("\nCurrently %d open RFQs (buyer requests) and %d active listings for this commodity.\n\n", openRFQCount, activeListingCount))
	sb.WriteString("Comment on supply/demand balance (RFQ count vs listing count) and whether asking prices and transacted prices look aligned or diverging. ")
	sb.WriteString("If there isn't enough data to say anything meaningful, say so plainly instead of speculating. Do not invent any numbers not given above. ")
	sb.WriteString("This is informational commentary, not financial advice -- do not phrase anything as a recommendation to buy or sell.")
	return sb.String()
}

// ---------- Contract Drafting ----------

type draftContractResponse struct {
	OrderID      uuid.UUID `json:"order_id"`
	ContractText string    `json:"contract_text"`
	Disclaimer   string    `json:"disclaimer"`
	GeneratedAt  time.Time `json:"generated_at"`
}

// DraftContract generates a plain-language draft sale agreement from a
// real Order's data (commodity, quantity, price, delivery address) -- the
// prompt is explicitly told to use only the given details and never invent
// party names or terms. Only the order's buyer or seller can request this,
// same access pattern as OrderHandler.GetOrderDetail.
// POST /api/v1/marketplace/orders/:id/ai/draft-contract
func (h *AIHandler) DraftContract(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	orderID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid order id", err)
		return
	}

	var order models.Order
	if err := database.DB.First(&order, "id = ?", orderID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "order not found", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch order", err)
		return
	}
	if order.BuyerID != userID {
		var seller models.Seller
		if err := database.DB.Where("id = ? AND user_id = ?", order.SellerID, userID).First(&seller).Error; err != nil {
			utils.Fail(c, http.StatusForbidden, "you don't have access to this order", nil)
			return
		}
	}

	contractText, err := h.gemini.GenerateInsights(buildContractPrompt(order))
	if err != nil {
		utils.Fail(c, http.StatusBadGateway, "AI contract drafting is unavailable right now", err)
		return
	}

	utils.Success(c, http.StatusOK, "contract draft generated", draftContractResponse{
		OrderID:      order.ID,
		ContractText: strings.TrimSpace(contractText),
		Disclaimer:   aiDraftDisclaimer,
		GeneratedAt:  time.Now(),
	})
}

func buildContractPrompt(order models.Order) string {
	var sb strings.Builder
	sb.WriteString("Draft a plain-language commodity sale agreement using ONLY the following details -- do not invent any party names, prices, or terms not given here:\n\n")
	sb.WriteString(fmt.Sprintf("Order reference: %s\n", order.ID))
	sb.WriteString(fmt.Sprintf("Commodity: %s\n", order.CommodityType))
	sb.WriteString(fmt.Sprintf("Quantity: %.2f %s\n", order.Quantity, order.Unit))
	sb.WriteString(fmt.Sprintf("Price per unit: %.2f\n", order.PricePerUnit))
	sb.WriteString(fmt.Sprintf("Total amount: %.2f\n", order.TotalAmount))
	sb.WriteString(fmt.Sprintf("Delivery address: %s\n", order.DeliveryAddress))
	sb.WriteString(fmt.Sprintf("Order placed: %s\n\n", order.CreatedAt.Format("2 January 2006")))
	sb.WriteString("Refer to the parties generically as \"the Buyer\" and \"the Seller\" (their real identities are on file with the platform, not included here). ")
	sb.WriteString("Include sections for: parties, subject matter (commodity/quantity/quality), price and payment terms, delivery terms, and a short standard dispute-resolution clause. ")
	sb.WriteString("Keep it clear and businesslike, not overly long. End with a clear note that this is a draft requiring legal review before signing.")
	return sb.String()
}

// ---------- Product Recommendation ----------

type recommendListingsRequest struct {
	Query string `json:"query" binding:"required,max=1000"`
}

type listingRecommendation struct {
	ListingID uuid.UUID `json:"listing_id"`
	Reasoning string    `json:"reasoning"`
}

// RecommendListings matches a buyer's plain-English requirement against
// currently active listings and asks Gemini to rank the best fits. Gemini
// only ever sees the candidate listings actually fetched below and is told
// never to invent an id -- and any id it returns anyway that isn't in that
// set is filtered out server-side as a second line of defense, so a
// hallucinated listing can't reach the response.
// POST /api/v1/marketplace/ai/recommend-listings
func (h *AIHandler) RecommendListings(c *gin.Context) {
	var req recommendListingsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	var listings []models.Listing
	if err := database.DB.Where("is_active = ?", true).Order("created_at DESC").Limit(100).Find(&listings).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch listings", err)
		return
	}
	if len(listings) == 0 {
		utils.Success(c, http.StatusOK, "no active listings to recommend from", gin.H{"recommendations": []listingRecommendation{}})
		return
	}

	reply, err := h.gemini.GenerateInsights(buildRecommendationPrompt(req.Query, listings))
	if err != nil {
		utils.Fail(c, http.StatusBadGateway, "AI recommendations are unavailable right now", err)
		return
	}

	var recs []listingRecommendation
	if err := json.Unmarshal([]byte(extractJSONArray(reply)), &recs); err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to parse AI response", err)
		return
	}

	validIDs := make(map[uuid.UUID]bool, len(listings))
	for _, l := range listings {
		validIDs[l.ID] = true
	}
	filtered := make([]listingRecommendation, 0, len(recs))
	for _, r := range recs {
		if validIDs[r.ListingID] {
			filtered = append(filtered, r)
		}
	}

	utils.Success(c, http.StatusOK, "recommendations generated", gin.H{"recommendations": filtered})
}

func buildRecommendationPrompt(query string, listings []models.Listing) string {
	var sb strings.Builder
	sb.WriteString("A buyer on a B2B energy commodity marketplace described this requirement:\n\n")
	sb.WriteString(fmt.Sprintf("%q\n\n", query))
	sb.WriteString("Here are the currently active listings (id, commodity, quantity available, unit, price per unit, grade/quality spec, location):\n\n")
	for _, l := range listings {
		sb.WriteString(fmt.Sprintf("- id=%s | %s | %.2f %s available | price %.2f/%s | grade: %s | location: %s\n",
			l.ID, l.CommodityType, l.Quantity, l.Unit, l.Price, l.Unit, orDash(l.Grade), orDash(l.Location)))
	}
	sb.WriteString("\nPick up to 5 of the BEST-FIT listings from the list above for this buyer's requirement, ranked best first. ")
	sb.WriteString("ONLY use listing ids that appear in the list above -- never invent an id. If nothing is a reasonable fit, return an empty array. ")
	sb.WriteString(`Respond with ONLY a JSON array, no other text, in this exact shape: [{"listing_id": "<uuid>", "reasoning": "<one sentence>"}]`)
	return sb.String()
}

func orDash(s string) string {
	if s == "" {
		return "-"
	}
	return s
}
