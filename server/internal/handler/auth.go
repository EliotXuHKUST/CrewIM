package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"regexp"

	"github.com/xiaozhong/command-center-server/internal/db"
	"github.com/xiaozhong/command-center-server/internal/middleware"
	"github.com/xiaozhong/command-center-server/internal/sms"
)

var phoneRegex = regexp.MustCompile(`^1[3-9]\d{9}$`)

type sendCodeRequest struct {
	Phone string `json:"phone"`
}

type loginRequest struct {
	Phone string `json:"phone"`
	Code  string `json:"code"`
}

type loginResponse struct {
	Token string   `json:"token"`
	User  userInfo `json:"user"`
}

type userInfo struct {
	ID          string `json:"id"`
	Phone       string `json:"phone"`
	Initialized bool   `json:"initialized"`
}

type AuthHandler struct {
	JWTSecret string
	SMSSender sms.Sender
	CodeStore *sms.CodeStore
	MockMode  bool
}

func (h *AuthHandler) SendCode(w http.ResponseWriter, r *http.Request) {
	var req sendCodeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}
	if !phoneRegex.MatchString(req.Phone) {
		http.Error(w, `{"error":"Invalid phone number"}`, http.StatusBadRequest)
		return
	}

	code := h.CodeStore.Generate(req.Phone)

	if err := h.SMSSender.Send(req.Phone, code); err != nil {
		http.Error(w, `{"error":"Failed to send SMS"}`, http.StatusInternalServerError)
		return
	}

	resp := map[string]interface{}{"success": true}
	if h.MockMode {
		resp["code"] = code
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}
	if !phoneRegex.MatchString(req.Phone) || len(req.Code) != 6 {
		http.Error(w, `{"error":"Phone and 6-digit code required"}`, http.StatusBadRequest)
		return
	}

	if h.MockMode && req.Code == "123456" {
		// fixed bypass code in mock mode
	} else if !h.CodeStore.Verify(req.Phone, req.Code) {
		http.Error(w, `{"error":"Invalid or expired verification code"}`, http.StatusUnauthorized)
		return
	}

	ctx := context.Background()

	var userID, phone string
	var initialized bool

	err := db.Pool.QueryRow(ctx,
		`SELECT u.id, u.phone, COALESCE(p.initialized, false)
		 FROM users u LEFT JOIN user_profiles p ON u.id = p.user_id
		 WHERE u.phone = $1`, req.Phone).Scan(&userID, &phone, &initialized)

	if err != nil {
		err = db.Pool.QueryRow(ctx,
			`INSERT INTO users (phone) VALUES ($1) RETURNING id, phone`, req.Phone).Scan(&userID, &phone)
		if err != nil {
			http.Error(w, `{"error":"Failed to create user"}`, http.StatusInternalServerError)
			return
		}
		db.Pool.Exec(ctx, `INSERT INTO user_profiles (user_id) VALUES ($1)`, userID)
		initialized = false
	}

	token, err := middleware.SignToken(h.JWTSecret, userID, phone)
	if err != nil {
		http.Error(w, `{"error":"Failed to generate token"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(loginResponse{
		Token: token,
		User:  userInfo{ID: userID, Phone: phone, Initialized: initialized},
	})
}
