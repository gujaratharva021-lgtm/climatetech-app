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

var (
errInspectionForbidden     = errors.New("forbidden")
errInspectionConflict      = errors.New("conflict")
errInspectionAlreadyExists = errors.New("inspection already exists for this order")
)

var inspectionActiveStatuses = []models.InspectionStatus{
models.InspectionStatusPending,
models.InspectionStatusAssigned,
models.InspectionStatusScheduled,
}

type InspectionHandler struct{}

func NewInspectionHandler() *InspectionHandler {
return &InspectionHandler{}
}

// ---------- Requesting inspection ----------

type createInspectionRequest struct {
InspectionType string `json:"inspection_type" binding:"required,oneof=pre_shipment post_delivery"`
Notes          string `json:"notes" binding:"omitempty,max=1000"`
}

// CreateInspectionRequest lets either party on an order request a quality
// inspection. Blocked if the order is cancelled or already has an active
// (non-terminal) inspection request.
// POST /api/v1/marketplace/orders/:id/inspection
func (h *InspectionHandler) CreateInspectionRequest(c *gin.Context) {
userID := c.MustGet("user_id").(uuid.UUID)

orderID, err := uuid.Parse(c.Param("id"))
if err != nil {
utils.Fail(c, http.StatusBadRequest, "invalid order id", err)
return
}

var req createInspectionRequest
if err := c.ShouldBindJSON(&req); err != nil {
utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
return
}

var inspection models.InspectionRequest
txErr := database.DB.Transaction(func(tx *gorm.DB) error {
var order models.Order
if err := tx.First(&order, "id = ?", orderID).Error; err != nil {
return err
}
if order.Status == models.OrderStatusCancelled {
return errInspectionConflict
}

role := models.InspectionRequesterBuyer
if order.BuyerID != userID {
var seller models.Seller
if err := tx.Where("id = ? AND user_id = ?", order.SellerID, userID).First(&seller).Error; err != nil {
return errInspectionForbidden
}
role = models.InspectionRequesterSeller
}

var existing models.InspectionRequest
err := tx.Where("order_id = ? AND status IN ?", orderID, inspectionActiveStatuses).First(&existing).Error
if err == nil {
return errInspectionAlreadyExists
}
if !errors.Is(err, gorm.ErrRecordNotFound) {
return err
}

inspection = models.InspectionRequest{
OrderID:        orderID,
RequesterID:    userID,
RequesterRole:  role,
InspectionType: models.InspectionType(req.InspectionType),
Notes:          req.Notes,
Status:         models.InspectionStatusPending,
}
return tx.Create(&inspection).Error
})

if txErr != nil {
switch {
case errors.Is(txErr, gorm.ErrRecordNotFound):
utils.Fail(c, http.StatusNotFound, "order not found", txErr)
case errors.Is(txErr, errInspectionForbidden):
utils.Fail(c, http.StatusForbidden, "you don't have access to this order", nil)
case errors.Is(txErr, errInspectionConflict):
utils.Fail(c, http.StatusConflict, "can't request inspection on a cancelled order", nil)
case errors.Is(txErr, errInspectionAlreadyExists):
utils.Fail(c, http.StatusConflict, "this order already has an active inspection request", nil)
default:
utils.Fail(c, http.StatusInternalServerError, "failed to create inspection request", txErr)
}
return
}

utils.Success(c, http.StatusCreated, "inspection request submitted", inspection)
}

// ---------- Viewing ----------

// GET /api/v1/marketplace/inspections/:id
func (h *InspectionHandler) GetInspectionRequest(c *gin.Context) {
userID := c.MustGet("user_id").(uuid.UUID)

id, err := uuid.Parse(c.Param("id"))
if err != nil {
utils.Fail(c, http.StatusBadRequest, "invalid inspection id", err)
return
}

var inspection models.InspectionRequest
if err := database.DB.First(&inspection, "id = ?", id).Error; err != nil {
if errors.Is(err, gorm.ErrRecordNotFound) {
utils.Fail(c, http.StatusNotFound, "inspection not found", err)
return
}
utils.Fail(c, http.StatusInternalServerError, "failed to fetch inspection", err)
return
}

isRequester := inspection.RequesterID == userID
isInspector := inspection.InspectorID != nil && *inspection.InspectorID == userID
if !isRequester && !isInspector {
utils.Fail(c, http.StatusForbidden, "you don't have access to this inspection", nil)
return
}

utils.Success(c, http.StatusOK, "inspection fetched", inspection)
}

// GET /api/v1/marketplace/my-inspections
func (h *InspectionHandler) GetMyInspections(c *gin.Context) {
userID := c.MustGet("user_id").(uuid.UUID)

var inspections []models.InspectionRequest
if err := database.DB.Where("requester_id = ?", userID).Order("created_at DESC").Find(&inspections).Error; err != nil {
utils.Fail(c, http.StatusInternalServerError, "failed to fetch your inspections", err)
return
}

utils.Success(c, http.StatusOK, "your inspections fetched", inspections)
}

// GET /api/v1/marketplace/inspector/assigned
func (h *InspectionHandler) GetAssignedInspections(c *gin.Context) {
userID := c.MustGet("user_id").(uuid.UUID)

var inspections []models.InspectionRequest
if err := database.DB.Where("inspector_id = ?", userID).Order("created_at DESC").Find(&inspections).Error; err != nil {
utils.Fail(c, http.StatusInternalServerError, "failed to fetch assigned inspections", err)
return
}

utils.Success(c, http.StatusOK, "assigned inspections fetched", inspections)
}

// ---------- Inspector actions ----------

type scheduleInspectionRequest struct {
ScheduledDate time.Time `json:"scheduled_date" binding:"required"`
}

// PUT /api/v1/marketplace/inspections/:id/schedule
func (h *InspectionHandler) ScheduleInspection(c *gin.Context) {
userID := c.MustGet("user_id").(uuid.UUID)

id, err := uuid.Parse(c.Param("id"))
if err != nil {
utils.Fail(c, http.StatusBadRequest, "invalid inspection id", err)
return
}

var req scheduleInspectionRequest
if err := c.ShouldBindJSON(&req); err != nil {
utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
return
}

var inspection models.InspectionRequest
if err := database.DB.First(&inspection, "id = ?", id).Error; err != nil {
if errors.Is(err, gorm.ErrRecordNotFound) {
utils.Fail(c, http.StatusNotFound, "inspection not found", err)
return
}
utils.Fail(c, http.StatusInternalServerError, "failed to fetch inspection", err)
return
}

if inspection.InspectorID == nil || *inspection.InspectorID != userID {
utils.Fail(c, http.StatusForbidden, "you are not the assigned inspector for this inspection", nil)
return
}
if inspection.Status != models.InspectionStatusAssigned {
utils.Fail(c, http.StatusConflict, "inspection must be assigned before it can be scheduled", nil)
return
}

updates := map[string]interface{}{
"status":         models.InspectionStatusScheduled,
"scheduled_date": &req.ScheduledDate,
}
if err := database.DB.Model(&inspection).Updates(updates).Error; err != nil {
utils.Fail(c, http.StatusInternalServerError, "failed to schedule inspection", err)
return
}

utils.Success(c, http.StatusOK, "inspection scheduled", nil)
}

type completeInspectionRequest struct {
Result        string `json:"result" binding:"required,oneof=pass fail conditional"`
Grade         string `json:"grade" binding:"omitempty,max=50"`
ReportNotes   string `json:"report_notes" binding:"omitempty,max=1000"`
ReportFileURL string `json:"report_file_url" binding:"omitempty,max=500"`
}

// PUT /api/v1/marketplace/inspections/:id/complete
func (h *InspectionHandler) CompleteInspection(c *gin.Context) {
userID := c.MustGet("user_id").(uuid.UUID)

id, err := uuid.Parse(c.Param("id"))
if err != nil {
utils.Fail(c, http.StatusBadRequest, "invalid inspection id", err)
return
}

var req completeInspectionRequest
if err := c.ShouldBindJSON(&req); err != nil {
utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
return
}

var inspection models.InspectionRequest
if err := database.DB.First(&inspection, "id = ?", id).Error; err != nil {
if errors.Is(err, gorm.ErrRecordNotFound) {
utils.Fail(c, http.StatusNotFound, "inspection not found", err)
return
}
utils.Fail(c, http.StatusInternalServerError, "failed to fetch inspection", err)
return
}

if inspection.InspectorID == nil || *inspection.InspectorID != userID {
utils.Fail(c, http.StatusForbidden, "you are not the assigned inspector for this inspection", nil)
return
}
if inspection.Status != models.InspectionStatusScheduled {
utils.Fail(c, http.StatusConflict, "inspection must be scheduled before it can be completed", nil)
return
}

now := time.Now()
updates := map[string]interface{}{
"status":          models.InspectionStatusCompleted,
"result":          req.Result,
"grade":           req.Grade,
"report_notes":    req.ReportNotes,
"report_file_url": req.ReportFileURL,
"completed_at":    &now,
}
if err := database.DB.Model(&inspection).Updates(updates).Error; err != nil {
utils.Fail(c, http.StatusInternalServerError, "failed to complete inspection", err)
return
}

utils.Success(c, http.StatusOK, "inspection completed", nil)
}

// ---------- Requester actions ----------

// PUT /api/v1/marketplace/inspections/:id/cancel
func (h *InspectionHandler) CancelInspection(c *gin.Context) {
userID := c.MustGet("user_id").(uuid.UUID)

id, err := uuid.Parse(c.Param("id"))
if err != nil {
utils.Fail(c, http.StatusBadRequest, "invalid inspection id", err)
return
}

var inspection models.InspectionRequest
if err := database.DB.First(&inspection, "id = ? AND requester_id = ?", id, userID).Error; err != nil {
if errors.Is(err, gorm.ErrRecordNotFound) {
utils.Fail(c, http.StatusNotFound, "inspection not found or not yours", err)
return
}
utils.Fail(c, http.StatusInternalServerError, "failed to fetch inspection", err)
return
}

allowed := false
for _, s := range inspectionActiveStatuses {
if inspection.Status == s {
allowed = true
break
}
}
if !allowed {
utils.Fail(c, http.StatusConflict, "this inspection can no longer be cancelled", nil)
return
}

if err := database.DB.Model(&inspection).Update("status", models.InspectionStatusCancelled).Error; err != nil {
utils.Fail(c, http.StatusInternalServerError, "failed to cancel inspection", err)
return
}

utils.Success(c, http.StatusOK, "inspection cancelled", nil)
}

// ---------- Admin ----------

// GET /api/v1/marketplace/admin/inspections?status=
func (h *InspectionHandler) ListAllInspectionsAdmin(c *gin.Context) {
page, limit, offset := utils.ParsePageLimit(c, 20, 100)

query := database.DB.Model(&models.InspectionRequest{})
if status := c.Query("status"); status != "" {
query = query.Where("status = ?", status)
}

var total int64
if err := query.Count(&total).Error; err != nil {
utils.Fail(c, http.StatusInternalServerError, "failed to count inspections", err)
return
}

var inspections []models.InspectionRequest
if err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&inspections).Error; err != nil {
utils.Fail(c, http.StatusInternalServerError, "failed to fetch inspections", err)
return
}

utils.Success(c, http.StatusOK, "inspections fetched", gin.H{
"inspections": inspections,
"page":        page,
"limit":       limit,
"total":       total,
})
}

type assignInspectorRequest struct {
InspectorID string `json:"inspector_id" binding:"required,uuid"`
}

// PUT /api/v1/marketplace/admin/inspections/:id/assign
func (h *InspectionHandler) AssignInspectorAdmin(c *gin.Context) {
id, err := uuid.Parse(c.Param("id"))
if err != nil {
utils.Fail(c, http.StatusBadRequest, "invalid inspection id", err)
return
}

var req assignInspectorRequest
if err := c.ShouldBindJSON(&req); err != nil {
utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
return
}
inspectorID, err := uuid.Parse(req.InspectorID)
if err != nil {
utils.Fail(c, http.StatusBadRequest, "invalid inspector id", err)
return
}

var inspection models.InspectionRequest
if err := database.DB.First(&inspection, "id = ?", id).Error; err != nil {
if errors.Is(err, gorm.ErrRecordNotFound) {
utils.Fail(c, http.StatusNotFound, "inspection not found", err)
return
}
utils.Fail(c, http.StatusInternalServerError, "failed to fetch inspection", err)
return
}

if inspection.Status != models.InspectionStatusPending {
utils.Fail(c, http.StatusConflict, "only a pending inspection can be assigned", nil)
return
}

var inspector models.User
if err := database.DB.First(&inspector, "id = ? AND role = ?", inspectorID, "inspector").Error; err != nil {
utils.Fail(c, http.StatusBadRequest, "inspector not found or user is not an inspector", err)
return
}

updates := map[string]interface{}{
"status":       models.InspectionStatusAssigned,
"inspector_id": &inspectorID,
}
if err := database.DB.Model(&inspection).Updates(updates).Error; err != nil {
utils.Fail(c, http.StatusInternalServerError, "failed to assign inspector", err)
return
}

utils.Success(c, http.StatusOK, "inspector assigned", nil)
}