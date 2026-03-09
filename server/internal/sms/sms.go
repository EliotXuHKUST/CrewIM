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

// CodeStore manages verification codes with expiration.
type CodeStore struct {
	mu    sync.RWMutex
	codes map[string]codeEntry // phone -> code entry
}

func NewCodeStore() *CodeStore {
	s := &CodeStore{codes: make(map[string]codeEntry)}
	go s.cleanup()
	return s
}

func (s *CodeStore) Generate(phone string) string {
	code := fmt.Sprintf("%06d", rand.Intn(1000000))
	s.mu.Lock()
	s.codes[phone] = codeEntry{
		Code:      code,
		ExpiresAt: time.Now().Add(5 * time.Minute),
	}
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
		s.mu.Lock()
		for phone, entry := range s.codes {
			if now.After(entry.ExpiresAt) {
				delete(s.codes, phone)
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
