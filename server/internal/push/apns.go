package push

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"

	"github.com/xiaozhong/command-center-server/internal/db"
)

type Pusher interface {
	Push(userID, title, body string) error
}

type APNsPusher struct {
	KeyID      string
	TeamID     string
	BundleID   string
	Production bool
}

type MockPusher struct{}

func (m *MockPusher) Push(userID, title, body string) error {
	slog.Info("Push mock", "userId", userID, "title", title, "body", body)
	return nil
}

func (p *APNsPusher) Push(userID, title, body string) error {
	ctx := context.Background()

	rows, err := db.Pool.Query(ctx,
		`SELECT device_token FROM push_tokens WHERE user_id = $1`, userID)
	if err != nil {
		return err
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var t string
		rows.Scan(&t)
		tokens = append(tokens, t)
	}

	if len(tokens) == 0 {
		return nil
	}

	for _, token := range tokens {
		if err := p.sendToAPNs(token, title, body); err != nil {
			slog.Warn("APNs push failed", "token", token[:8]+"...", "err", err)
		}
	}
	return nil
}

func (p *APNsPusher) sendToAPNs(token, title, body string) error {
	host := "https://api.sandbox.push.apple.com"
	if p.Production {
		host = "https://api.push.apple.com"
	}

	payload := map[string]any{
		"aps": map[string]any{
			"alert": map[string]string{"title": title, "body": body},
			"sound": "default",
			"badge": 1,
		},
	}
	data, _ := json.Marshal(payload)

	url := fmt.Sprintf("%s/3/device/%s", host, token)
	req, _ := http.NewRequest("POST", url, bytes.NewReader(data))
	req.Header.Set("apns-topic", p.BundleID)
	req.Header.Set("apns-push-type", "alert")
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("APNs returned %d", resp.StatusCode)
	}
	return nil
}

func NewPusher(provider string) Pusher {
	if provider == "apns" {
		return &APNsPusher{}
	}
	return &MockPusher{}
}

func RegisterToken(userID, deviceToken, platform string) error {
	_, err := db.Pool.Exec(context.Background(),
		`INSERT INTO push_tokens (user_id, device_token, platform)
		 VALUES ($1, $2, $3)
		 ON CONFLICT (user_id, device_token) DO UPDATE SET updated_at = NOW()`,
		userID, deviceToken, platform)
	return err
}
