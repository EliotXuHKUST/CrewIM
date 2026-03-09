package handler

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/xiaozhong/command-center-server/internal/crypto"
	"github.com/xiaozhong/command-center-server/internal/db"
	"github.com/xiaozhong/command-center-server/internal/middleware"
)

type AccountHandler struct {
	EncryptKey string
}

type accountRequest struct {
	Platform    string                 `json:"platform"`
	DisplayName string                `json:"display_name"`
	Credentials map[string]interface{} `json:"credentials"`
}

type accountResponse struct {
	ID          string `json:"id"`
	Platform    string `json:"platform"`
	DisplayName string `json:"display_name"`
	CreatedAt   string `json:"created_at"`
	UpdatedAt   string `json:"updated_at"`
}

func (h *AccountHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	ctx := context.Background()

	rows, err := db.Pool.Query(ctx,
		`SELECT id, platform, display_name, created_at, updated_at
		 FROM user_accounts WHERE user_id = $1 ORDER BY created_at`, userID)
	if err != nil {
		http.Error(w, `{"error":"Failed to list accounts"}`, http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	accounts := []accountResponse{}
	for rows.Next() {
		var a accountResponse
		if err := rows.Scan(&a.ID, &a.Platform, &a.DisplayName, &a.CreatedAt, &a.UpdatedAt); err != nil {
			continue
		}
		accounts = append(accounts, a)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"accounts": accounts})
}

func (h *AccountHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	var req accountRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}
	if req.Platform == "" || req.Credentials == nil {
		http.Error(w, `{"error":"platform and credentials required"}`, http.StatusBadRequest)
		return
	}

	credJSON, _ := json.Marshal(req.Credentials)
	encrypted, err := crypto.Encrypt(string(credJSON), h.EncryptKey)
	if err != nil {
		http.Error(w, `{"error":"Encryption failed"}`, http.StatusInternalServerError)
		return
	}

	ctx := context.Background()
	var id string
	err = db.Pool.QueryRow(ctx,
		`INSERT INTO user_accounts (user_id, platform, display_name, credentials_enc)
		 VALUES ($1, $2, $3, $4) RETURNING id`,
		userID, req.Platform, req.DisplayName, encrypted).Scan(&id)
	if err != nil {
		http.Error(w, `{"error":"Failed to create account"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"id": id})
}

func (h *AccountHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	accountID := r.PathValue("id")

	var req accountRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}

	ctx := context.Background()

	if req.Credentials != nil {
		credJSON, _ := json.Marshal(req.Credentials)
		encrypted, err := crypto.Encrypt(string(credJSON), h.EncryptKey)
		if err != nil {
			http.Error(w, `{"error":"Encryption failed"}`, http.StatusInternalServerError)
			return
		}
		_, err = db.Pool.Exec(ctx,
			`UPDATE user_accounts SET display_name = COALESCE(NULLIF($1, ''), display_name),
			 credentials_enc = $2, updated_at = NOW()
			 WHERE id = $3 AND user_id = $4`,
			req.DisplayName, encrypted, accountID, userID)
		if err != nil {
			http.Error(w, `{"error":"Update failed"}`, http.StatusInternalServerError)
			return
		}
	} else if req.DisplayName != "" {
		_, err := db.Pool.Exec(ctx,
			`UPDATE user_accounts SET display_name = $1, updated_at = NOW()
			 WHERE id = $2 AND user_id = $3`,
			req.DisplayName, accountID, userID)
		if err != nil {
			http.Error(w, `{"error":"Update failed"}`, http.StatusInternalServerError)
			return
		}
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"success":true}`))
}

func (h *AccountHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	accountID := r.PathValue("id")

	ctx := context.Background()
	_, err := db.Pool.Exec(ctx,
		`DELETE FROM user_accounts WHERE id = $1 AND user_id = $2`, accountID, userID)
	if err != nil {
		http.Error(w, `{"error":"Delete failed"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"success":true}`))
}
