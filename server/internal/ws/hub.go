package ws

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"sync"

	"github.com/gorilla/websocket"
	"github.com/golang-jwt/jwt/v5"
	"github.com/xiaozhong/command-center-server/internal/model"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type Hub struct {
	mu    sync.RWMutex
	conns map[string]map[*websocket.Conn]bool // userID -> connections
	secret string
}

func NewHub(jwtSecret string) *Hub {
	return &Hub{
		conns:  make(map[string]map[*websocket.Conn]bool),
		secret: jwtSecret,
	}
}

func (h *Hub) HandleWS(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		slog.Error("websocket upgrade failed", "err", err)
		return
	}

	authenticated := false
	var userID string

	defer func() {
		conn.Close()
		if userID != "" {
			h.removeConn(userID, conn)
		}
	}()

	for {
		_, msg, err := conn.ReadMessage()
		if err != nil {
			break
		}

		var envelope struct {
			Type  string `json:"type"`
			Token string `json:"token,omitempty"`
		}
		if json.Unmarshal(msg, &envelope) != nil {
			continue
		}

		if !authenticated && envelope.Type == "auth" {
			uid := h.verifyToken(envelope.Token)
			if uid == "" {
				conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"auth_error"}`))
				return
			}
			authenticated = true
			userID = uid
			h.addConn(userID, conn)
			conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"auth_ok"}`))
			continue
		}

		if !authenticated {
			conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"auth_required"}`))
			return
		}
	}
}

func (h *Hub) Send(userID string, event model.PushEvent) {
	h.mu.RLock()
	conns := h.conns[userID]
	h.mu.RUnlock()

	if len(conns) == 0 {
		return
	}

	data, err := json.Marshal(event)
	if err != nil {
		return
	}

	h.mu.RLock()
	defer h.mu.RUnlock()
	for conn := range conns {
		if err := conn.WriteMessage(websocket.TextMessage, data); err != nil {
			go h.removeConn(userID, conn)
		}
	}
}

func (h *Hub) addConn(userID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.conns[userID] == nil {
		h.conns[userID] = make(map[*websocket.Conn]bool)
	}
	h.conns[userID][conn] = true
}

func (h *Hub) removeConn(userID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	delete(h.conns[userID], conn)
	if len(h.conns[userID]) == 0 {
		delete(h.conns, userID)
	}
}

func (h *Hub) verifyToken(tokenStr string) string {
	token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
		return []byte(h.secret), nil
	})
	if err != nil || !token.Valid {
		return ""
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return ""
	}
	uid, _ := claims["userId"].(string)
	return uid
}
