package sms

import (
	"fmt"
	"log/slog"
	"math/rand"
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
	// TODO: integrate with Tencent Cloud SMS SDK
	return fmt.Errorf("tencent cloud SMS not yet implemented")
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
