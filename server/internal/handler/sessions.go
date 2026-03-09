package handler

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/xiaozhong/command-center-server/internal/db"
	"github.com/xiaozhong/command-center-server/internal/middleware"
)

type SessionHandler struct{}

func (h *SessionHandler) CreateSession(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(string)

	var req struct {
		ID    string  `json:"id"`
		Title *string `json:"title"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid body"}`, http.StatusBadRequest)
		return
	}

	var id string
	var createdAt time.Time

	if req.ID != "" {
		_, err := db.Pool.Exec(r.Context(),
			`INSERT INTO sessions (id, user_id, title) VALUES ($1, $2, $3)
			 ON CONFLICT (id) DO UPDATE SET title = COALESCE(EXCLUDED.title, sessions.title), updated_at = NOW()`,
			req.ID, userID, req.Title)
		if err != nil {
			slog.Error("Create session failed", "err", err)
			http.Error(w, `{"error":"db error"}`, http.StatusInternalServerError)
			return
		}
		id = req.ID
		createdAt = time.Now()
	} else {
		err := db.Pool.QueryRow(r.Context(),
			`INSERT INTO sessions (user_id, title) VALUES ($1, $2) RETURNING id, created_at`,
			userID, req.Title).Scan(&id, &createdAt)
		if err != nil {
			slog.Error("Create session failed", "err", err)
			http.Error(w, `{"error":"db error"}`, http.StatusInternalServerError)
			return
		}
	}

	json.NewEncoder(w).Encode(map[string]any{
		"id":        id,
		"title":     req.Title,
		"createdAt": createdAt.Format(time.RFC3339),
	})
}

func (h *SessionHandler) ListSessions(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(string)

	rows, err := db.Pool.Query(r.Context(),
		`SELECT s.id, s.title, s.created_at, s.updated_at,
		        (SELECT input_text FROM tasks WHERE session_id = s.id ORDER BY created_at DESC LIMIT 1) AS last_message
		 FROM sessions s
		 WHERE s.user_id = $1
		 ORDER BY s.updated_at DESC
		 LIMIT 50`, userID)
	if err != nil {
		slog.Error("List sessions failed", "err", err)
		http.Error(w, `{"error":"db error"}`, http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var sessions []map[string]any
	for rows.Next() {
		var id string
		var title *string
		var createdAt, updatedAt time.Time
		var lastMsg *string

		if err := rows.Scan(&id, &title, &createdAt, &updatedAt, &lastMsg); err != nil {
			continue
		}
		s := map[string]any{
			"id":        id,
			"title":     title,
			"createdAt": createdAt.Format(time.RFC3339),
			"updatedAt": updatedAt.Format(time.RFC3339),
		}
		if lastMsg != nil {
			s["lastMessage"] = *lastMsg
		}
		sessions = append(sessions, s)
	}

	if sessions == nil {
		sessions = []map[string]any{}
	}

	json.NewEncoder(w).Encode(map[string]any{"sessions": sessions})
}

func (h *SessionHandler) UpdateSession(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(string)
	sessionID := r.PathValue("id")

	var req struct {
		Title string `json:"title"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid body"}`, http.StatusBadRequest)
		return
	}

	_, err := db.Pool.Exec(r.Context(),
		`UPDATE sessions SET title = $1, updated_at = NOW() WHERE id = $2 AND user_id = $3`,
		req.Title, sessionID, userID)
	if err != nil {
		slog.Error("Update session failed", "err", err)
		http.Error(w, `{"error":"db error"}`, http.StatusInternalServerError)
		return
	}

	json.NewEncoder(w).Encode(map[string]any{"ok": true})
}

func (h *SessionHandler) DeleteSession(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(string)
	sessionID := r.PathValue("id")

	_, err := db.Pool.Exec(r.Context(),
		`DELETE FROM sessions WHERE id = $1 AND user_id = $2`, sessionID, userID)
	if err != nil {
		slog.Error("Delete session failed", "err", err)
		http.Error(w, `{"error":"db error"}`, http.StatusInternalServerError)
		return
	}

	json.NewEncoder(w).Encode(map[string]any{"ok": true})
}
