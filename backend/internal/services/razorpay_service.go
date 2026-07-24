package services

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// RazorpayService talks to Razorpay's plain REST API directly (Basic Auth
// with key id/secret) rather than depending on a third-party SDK -- order
// creation, refunds, and HMAC signature verification are simple enough that
// pulling in an extra dependency (and trusting its supply chain) isn't
// worth it.
type RazorpayService struct {
	KeyID     string
	KeySecret string
	Client    *http.Client
}

func NewRazorpayService(keyID, keySecret string) *RazorpayService {
	return &RazorpayService{
		KeyID:     keyID,
		KeySecret: keySecret,
		Client:    &http.Client{Timeout: 15 * time.Second},
	}
}

type razorpayCreateOrderRequest struct {
	Amount   int64  `json:"amount"` // paise
	Currency string `json:"currency"`
	Receipt  string `json:"receipt"`
	// PaymentCapture=1: Razorpay auto-captures on successful authorization,
	// instead of leaving the payment in "authorized" state awaiting a
	// separate manual capture call this project doesn't otherwise make.
	PaymentCapture int `json:"payment_capture"`
}

type razorpayErrorBody struct {
	Description string `json:"description"`
}

type razorpayOrderResponse struct {
	ID       string             `json:"id"`
	Amount   int64              `json:"amount"`
	Currency string             `json:"currency"`
	Status   string             `json:"status"`
	Error    *razorpayErrorBody `json:"error"`
}

// CreateOrder creates a Razorpay order for amountRupees (converted to paise
// here, since that's the unit Razorpay's API expects) and returns the
// Razorpay order id to hand to the frontend Checkout widget. receipt is an
// arbitrary reference string echoed back by Razorpay -- this project passes
// the local Order's id, so a Razorpay dashboard lookup can be tied back to it.
func (s *RazorpayService) CreateOrder(amountRupees float64, receipt string) (string, error) {
	if s.KeyID == "" || s.KeySecret == "" {
		return "", fmt.Errorf("razorpay is not configured (RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET missing)")
	}

	amountPaise := int64(amountRupees*100 + 0.5) // round to nearest paisa

	reqBody, err := json.Marshal(razorpayCreateOrderRequest{
		Amount:         amountPaise,
		Currency:       "INR",
		Receipt:        receipt,
		PaymentCapture: 1,
	})
	if err != nil {
		return "", err
	}

	req, err := http.NewRequest(http.MethodPost, "https://api.razorpay.com/v1/orders", bytes.NewReader(reqBody))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.SetBasicAuth(s.KeyID, s.KeySecret)

	resp, err := s.Client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var result razorpayOrderResponse
	if err := json.Unmarshal(respBody, &result); err != nil {
		return "", fmt.Errorf("failed to parse razorpay response: %w", err)
	}

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		msg := fmt.Sprintf("razorpay returned status %d", resp.StatusCode)
		if result.Error != nil && result.Error.Description != "" {
			msg = result.Error.Description
		}
		return "", fmt.Errorf("%s", msg)
	}

	return result.ID, nil
}

// VerifyPaymentSignature checks the signature Razorpay Checkout hands back
// to the frontend after a successful payment, per Razorpay's documented
// scheme: hex(HMAC-SHA256("<order_id>|<payment_id>", key_secret)). This is
// the actual proof of payment -- the order/payment ids alone prove nothing,
// since a client could send made-up ids without this check.
func (s *RazorpayService) VerifyPaymentSignature(orderID, paymentID, signature string) bool {
	if s.KeySecret == "" {
		return false
	}
	return hmacHexEqual(orderID+"|"+paymentID, s.KeySecret, signature)
}

// VerifyWebhookSignature checks the X-Razorpay-Signature header on incoming
// webhook events: hex(HMAC-SHA256(raw request body, webhook secret)). The
// webhook secret is separate from KeySecret -- configured independently in
// the Razorpay dashboard under Webhooks.
func (s *RazorpayService) VerifyWebhookSignature(rawBody []byte, signature, webhookSecret string) bool {
	if webhookSecret == "" {
		return false
	}
	return hmacHexEqual(string(rawBody), webhookSecret, signature)
}

// hmacHexEqual is shared by both signature checks above. Uses hmac.Equal
// (constant-time) rather than == to compare, so this doesn't leak timing
// information about how much of the signature matched.
func hmacHexEqual(payload, secret, signature string) bool {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(payload))
	expected := hex.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(expected), []byte(signature))
}

type razorpayRefundResponse struct {
	ID     string             `json:"id"`
	Status string             `json:"status"`
	Error  *razorpayErrorBody `json:"error"`
}

// CreateRefund issues a full refund for a captured payment (amount omitted
// from the request body = Razorpay refunds the full captured amount).
func (s *RazorpayService) CreateRefund(paymentID string) (string, error) {
	if s.KeyID == "" || s.KeySecret == "" {
		return "", fmt.Errorf("razorpay is not configured (RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET missing)")
	}

	url := fmt.Sprintf("https://api.razorpay.com/v1/payments/%s/refund", paymentID)
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader([]byte("{}")))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.SetBasicAuth(s.KeyID, s.KeySecret)

	resp, err := s.Client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var result razorpayRefundResponse
	if err := json.Unmarshal(respBody, &result); err != nil {
		return "", fmt.Errorf("failed to parse razorpay response: %w", err)
	}

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		msg := fmt.Sprintf("razorpay returned status %d", resp.StatusCode)
		if result.Error != nil && result.Error.Description != "" {
			msg = result.Error.Description
		}
		return "", fmt.Errorf("%s", msg)
	}

	return result.ID, nil
}
