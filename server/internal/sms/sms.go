package sms

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"math/rand"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"
)

type Sender interface {
	Send(phone, code string) error
}

// MockSender logs the code instead of sending a real SMS.
// In mock mode, any 6-digit code is accepted; the fixed code "123456" always works.
type MockSender struct{}

func (m *MockSender) Send(phone, code string) error {
	slog.Info("SMS mock", "phone", phone, "code", code)
	return nil
}

// TencentCloudSender is a placeholder for real Tencent Cloud SMS integration.
type TencentCloudSender struct {
	SDKAppID  string
	SignName  string
	TemplateID string
	SecretID  string
	SecretKey string
}

func (t *TencentCloudSender) Send(phone, code string) error {
	if t.SDKAppID == "" || t.SecretID == "" || t.SecretKey == "" {
		return fmt.Errorf("tencent SMS config incomplete")
	}

	phoneNumber := phone
	if !strings.HasPrefix(phone, "+") {
		phoneNumber = "+86" + phone
	}

	payload := map[string]any{
		"SmsSdkAppId":  t.SDKAppID,
		"SignName":     t.SignName,
		"TemplateId":   t.TemplateID,
		"PhoneNumberSet": []string{phoneNumber},
		"TemplateParamSet": []string{code, "5"},
	}
	body, _ := json.Marshal(payload)

	host := "sms.tencentcloudapi.com"
	service := "sms"
	action := "SendSms"
	version := "2021-01-11"
	timestamp := time.Now().Unix()

	authorization := t.signV3(host, service, action, version, timestamp, body)

	req, _ := http.NewRequest("POST", "https://"+host, strings.NewReader(string(body)))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Host", host)
	req.Header.Set("X-TC-Action", action)
	req.Header.Set("X-TC-Version", version)
	req.Header.Set("X-TC-Timestamp", strconv.FormatInt(timestamp, 10))
	req.Header.Set("Authorization", authorization)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("SMS HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	slog.Info("Tencent SMS response", "status", resp.StatusCode, "body", string(respBody))

	if resp.StatusCode != 200 {
		return fmt.Errorf("SMS API returned %d: %s", resp.StatusCode, string(respBody))
	}

	var result struct {
		Response struct {
			SendStatusSet []struct {
				Code    string `json:"Code"`
				Message string `json:"Message"`
			} `json:"SendStatusSet"`
			Error *struct {
				Code    string `json:"Code"`
				Message string `json:"Message"`
			} `json:"Error"`
		} `json:"Response"`
	}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return fmt.Errorf("parse SMS response: %w", err)
	}
	if result.Response.Error != nil {
		return fmt.Errorf("SMS API error: %s - %s", result.Response.Error.Code, result.Response.Error.Message)
	}
	if len(result.Response.SendStatusSet) > 0 && result.Response.SendStatusSet[0].Code != "Ok" {
		return fmt.Errorf("SMS send failed: %s", result.Response.SendStatusSet[0].Message)
	}

	return nil
}

func (t *TencentCloudSender) signV3(host, service, action, version string, timestamp int64, payload []byte) string {
	date := time.Unix(timestamp, 0).UTC().Format("2006-01-02")
	canonicalRequest := fmt.Sprintf("POST\n/\n\ncontent-type:application/json\nhost:%s\n\ncontent-type;host\n%s",
		host, sha256Hex(payload))
	stringToSign := fmt.Sprintf("TC3-HMAC-SHA256\n%d\n%s/%s/tc3_request\n%s",
		timestamp, date, service, sha256Hex([]byte(canonicalRequest)))

	secretDate := hmacSHA256([]byte("TC3"+t.SecretKey), date)
	secretService := hmacSHA256(secretDate, service)
	secretSigning := hmacSHA256(secretService, "tc3_request")
	signature := hex.EncodeToString(hmacSHA256(secretSigning, stringToSign))

	return fmt.Sprintf("TC3-HMAC-SHA256 Credential=%s/%s/%s/tc3_request, SignedHeaders=content-type;host, Signature=%s",
		t.SecretID, date, service, signature)
}

func hmacSHA256(key []byte, msg string) []byte {
	h := hmac.New(sha256.New, key)
	h.Write([]byte(msg))
	return h.Sum(nil)
}

func sha256Hex(data []byte) string {
	h := sha256.Sum256(data)
	return hex.EncodeToString(h[:])
}

type codeEntry struct {
	Code      string
	ExpiresAt time.Time
}

// CodeStore manages verification codes with expiration and rate limiting.
type CodeStore struct {
	mu      sync.RWMutex
	codes   map[string]codeEntry   // phone -> code entry
	sends   map[string][]time.Time // phone -> send timestamps for rate limiting
}

func NewCodeStore() *CodeStore {
	s := &CodeStore{
		codes: make(map[string]codeEntry),
		sends: make(map[string][]time.Time),
	}
	go s.cleanup()
	return s
}

// CheckRateLimit returns an error message if the phone is rate-limited.
// Limits: 1 SMS per 60 seconds, 5 SMS per hour.
func (s *CodeStore) CheckRateLimit(phone string) string {
	s.mu.RLock()
	defer s.mu.RUnlock()

	timestamps := s.sends[phone]
	if len(timestamps) == 0 {
		return ""
	}

	now := time.Now()
	last := timestamps[len(timestamps)-1]
	if now.Sub(last) < 60*time.Second {
		return "发送太频繁，请稍后再试"
	}

	hourAgo := now.Add(-time.Hour)
	count := 0
	for _, t := range timestamps {
		if t.After(hourAgo) {
			count++
		}
	}
	if count >= 5 {
		return "发送次数过多，请一小时后再试"
	}
	return ""
}

func (s *CodeStore) Generate(phone string) string {
	code := fmt.Sprintf("%06d", rand.Intn(1000000))
	now := time.Now()
	s.mu.Lock()
	s.codes[phone] = codeEntry{
		Code:      code,
		ExpiresAt: now.Add(5 * time.Minute),
	}
	s.sends[phone] = append(s.sends[phone], now)
	s.mu.Unlock()
	return code
}

func (s *CodeStore) Verify(phone, code string) bool {
	s.mu.RLock()
	entry, ok := s.codes[phone]
	s.mu.RUnlock()
	if !ok || time.Now().After(entry.ExpiresAt) {
		return false
	}
	if entry.Code == code {
		s.mu.Lock()
		delete(s.codes, phone)
		s.mu.Unlock()
		return true
	}
	return false
}

func (s *CodeStore) cleanup() {
	ticker := time.NewTicker(time.Minute)
	for range ticker.C {
		now := time.Now()
		hourAgo := now.Add(-time.Hour)
		s.mu.Lock()
		for phone, entry := range s.codes {
			if now.After(entry.ExpiresAt) {
				delete(s.codes, phone)
			}
		}
		for phone, timestamps := range s.sends {
			var kept []time.Time
			for _, t := range timestamps {
				if t.After(hourAgo) {
					kept = append(kept, t)
				}
			}
			if len(kept) == 0 {
				delete(s.sends, phone)
			} else {
				s.sends[phone] = kept
			}
		}
		s.mu.Unlock()
	}
}

func NewSender(provider string, cfg *TencentCloudSender) Sender {
	if provider == "tencent" && cfg != nil {
		return cfg
	}
	return &MockSender{}
}
