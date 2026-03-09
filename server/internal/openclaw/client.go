package openclaw

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/xiaozhong/command-center-server/internal/db"
)

type MessageCallback func(userID string, event map[string]interface{})

type Client struct {
	mu        sync.RWMutex
	conns     map[string]*userConn // userID -> connection
	onMessage MessageCallback
}

type userConn struct {
	ws         *websocket.Conn
	gatewayURL string
	cancel     context.CancelFunc
}

func NewClient(onMessage MessageCallback) *Client {
	return &Client{
		conns:     make(map[string]*userConn),
		onMessage: onMessage,
	}
}

func (c *Client) GetGatewayURL(userID string) string {
	ctx := context.Background()
	var profile json.RawMessage
	err := db.Pool.QueryRow(ctx,
		`SELECT profile FROM user_profiles WHERE user_id = $1`, userID).Scan(&profile)
	if err != nil {
		return ""
	}
	var p map[string]interface{}
	if json.Unmarshal(profile, &p) != nil {
		return ""
	}
	url, _ := p["openclaw_gateway_url"].(string)
	return url
}

func (c *Client) HasConnection(userID string) bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	_, ok := c.conns[userID]
	return ok
}

func (c *Client) EnsureConnected(userID string) error {
	if c.HasConnection(userID) {
		return nil
	}

	gatewayURL := c.GetGatewayURL(userID)
	if gatewayURL == "" {
		return fmt.Errorf("no OpenClaw gateway URL configured")
	}

	return c.connect(userID, gatewayURL)
}

func (c *Client) connect(userID, gatewayURL string) error {
	ws, _, err := websocket.DefaultDialer.Dial(gatewayURL, nil)
	if err != nil {
		return fmt.Errorf("OpenClaw dial: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	uc := &userConn{ws: ws, gatewayURL: gatewayURL, cancel: cancel}

	c.mu.Lock()
	if old, ok := c.conns[userID]; ok {
		old.cancel()
		old.ws.Close()
	}
	c.conns[userID] = uc
	c.mu.Unlock()

	slog.Info("OpenClaw connected", "userID", userID, "gateway", gatewayURL)

	go c.readLoop(ctx, userID, uc)
	go c.heartbeat(ctx, userID, uc)

	return nil
}

func (c *Client) readLoop(ctx context.Context, userID string, uc *userConn) {
	defer func() {
		c.mu.Lock()
		if current, ok := c.conns[userID]; ok && current == uc {
			delete(c.conns, userID)
		}
		c.mu.Unlock()
		uc.ws.Close()
	}()

	for {
		select {
		case <-ctx.Done():
			return
		default:
		}

		_, msg, err := uc.ws.ReadMessage()
		if err != nil {
			slog.Warn("OpenClaw read error, will reconnect", "userID", userID, "err", err)
			go c.reconnect(userID, uc.gatewayURL)
			return
		}

		var event map[string]interface{}
		if json.Unmarshal(msg, &event) != nil {
			continue
		}

		if c.onMessage != nil {
			c.onMessage(userID, event)
		}
	}
}

func (c *Client) heartbeat(ctx context.Context, userID string, uc *userConn) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := uc.ws.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (c *Client) reconnect(userID, gatewayURL string) {
	for i := 0; i < 10; i++ {
		delay := time.Duration(1<<uint(i)) * time.Second
		if delay > 30*time.Second {
			delay = 30 * time.Second
		}
		time.Sleep(delay)

		if err := c.connect(userID, gatewayURL); err == nil {
			slog.Info("OpenClaw reconnected", "userID", userID)
			return
		}
	}
	slog.Error("OpenClaw reconnect gave up", "userID", userID)
}

func (c *Client) SendMessage(userID, text string) error {
	c.mu.RLock()
	uc, ok := c.conns[userID]
	c.mu.RUnlock()

	if !ok {
		return fmt.Errorf("not connected to OpenClaw gateway")
	}

	msg := map[string]interface{}{
		"type":    "message",
		"content": text,
	}
	data, _ := json.Marshal(msg)
	return uc.ws.WriteMessage(websocket.TextMessage, data)
}

func (c *Client) Disconnect(userID string) {
	c.mu.Lock()
	if uc, ok := c.conns[userID]; ok {
		uc.cancel()
		uc.ws.Close()
		delete(c.conns, userID)
	}
	c.mu.Unlock()
}

func (c *Client) Close() {
	c.mu.Lock()
	defer c.mu.Unlock()
	for _, uc := range c.conns {
		uc.cancel()
		uc.ws.Close()
	}
	c.conns = make(map[string]*userConn)
}
