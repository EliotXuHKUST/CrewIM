package handler

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/smtp"
	"os"
	"regexp"
	"strings"

	"github.com/xiaozhong/command-center-server/internal/db"
	"github.com/xiaozhong/command-center-server/internal/middleware"
	"github.com/xiaozhong/command-center-server/internal/sms"
)

var phoneRegex = regexp.MustCompile(`^\+?\d{6,15}$`)

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

	phone := req.Phone
	if !strings.HasPrefix(phone, "+") {
		phone = "+86" + phone
	}
	if !strings.HasPrefix(phone, "+86") {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "International numbers not supported for SMS. Please use email or Apple Sign-In."})
		return
	}

	if msg := h.CodeStore.CheckRateLimit(phone); msg != "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusTooManyRequests)
		json.NewEncoder(w).Encode(map[string]string{"error": msg})
		return
	}

	code := h.CodeStore.Generate(phone)

	if err := h.SMSSender.Send(phone, code); err != nil {
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

func (h *AuthHandler) RefreshToken(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	ctx := context.Background()

	var phone *string
	db.Pool.QueryRow(ctx, `SELECT phone FROM users WHERE id = $1`, userID).Scan(&phone)

	phoneStr := ""
	if phone != nil {
		phoneStr = *phone
	}

	token, err := middleware.SignToken(h.JWTSecret, userID, phoneStr)
	if err != nil {
		http.Error(w, `{"error":"Failed to generate token"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"token": token})
}

func (h *AuthHandler) AppleLogin(w http.ResponseWriter, r *http.Request) {
	var body struct {
		IdentityToken string `json:"identity_token"`
		DisplayName   string `json:"display_name"`
	}
	json.NewDecoder(r.Body).Decode(&body)
	if body.IdentityToken == "" {
		http.Error(w, `{"error":"identity_token required"}`, http.StatusBadRequest)
		return
	}

	appleID, email, err := verifyAppleToken(body.IdentityToken)
	if err != nil {
		http.Error(w, `{"error":"Invalid Apple token"}`, http.StatusUnauthorized)
		return
	}

	ctx := context.Background()
	userID, initialized := h.findOrCreateUser(ctx, "apple_id", appleID, email, body.DisplayName)
	if userID == "" {
		http.Error(w, `{"error":"Failed to create user"}`, http.StatusInternalServerError)
		return
	}

	token, _ := middleware.SignToken(h.JWTSecret, userID, "")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(loginResponse{
		Token: token,
		User:  userInfo{ID: userID, Initialized: initialized},
	})
}

func (h *AuthHandler) GoogleLogin(w http.ResponseWriter, r *http.Request) {
	var body struct {
		IDToken     string `json:"id_token"`
		DisplayName string `json:"display_name"`
	}
	json.NewDecoder(r.Body).Decode(&body)
	if body.IDToken == "" {
		http.Error(w, `{"error":"id_token required"}`, http.StatusBadRequest)
		return
	}

	googleID, email, err := verifyGoogleToken(body.IDToken)
	if err != nil {
		http.Error(w, `{"error":"Invalid Google token"}`, http.StatusUnauthorized)
		return
	}

	ctx := context.Background()
	userID, initialized := h.findOrCreateUser(ctx, "google_id", googleID, email, body.DisplayName)
	if userID == "" {
		http.Error(w, `{"error":"Failed to create user"}`, http.StatusInternalServerError)
		return
	}

	token, _ := middleware.SignToken(h.JWTSecret, userID, "")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(loginResponse{
		Token: token,
		User:  userInfo{ID: userID, Initialized: initialized},
	})
}

func (h *AuthHandler) EmailLogin(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Email string `json:"email"`
		Code  string `json:"code"`
	}
	json.NewDecoder(r.Body).Decode(&body)
	if body.Email == "" || len(body.Code) != 6 {
		http.Error(w, `{"error":"Email and 6-digit code required"}`, http.StatusBadRequest)
		return
	}

	if h.MockMode && body.Code == "123456" {
		// bypass in mock mode
	} else if !h.CodeStore.Verify(body.Email, body.Code) {
		http.Error(w, `{"error":"Invalid or expired verification code"}`, http.StatusUnauthorized)
		return
	}

	ctx := context.Background()
	userID, initialized := h.findOrCreateUser(ctx, "email", body.Email, body.Email, "")
	if userID == "" {
		http.Error(w, `{"error":"Failed to create user"}`, http.StatusInternalServerError)
		return
	}

	token, _ := middleware.SignToken(h.JWTSecret, userID, "")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(loginResponse{
		Token: token,
		User:  userInfo{ID: userID, Initialized: initialized},
	})
}

func (h *AuthHandler) SendEmailCode(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Email string `json:"email"`
	}
	json.NewDecoder(r.Body).Decode(&body)
	if body.Email == "" {
		http.Error(w, `{"error":"Email required"}`, http.StatusBadRequest)
		return
	}

	if msg := h.CodeStore.CheckRateLimit(body.Email); msg != "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusTooManyRequests)
		json.NewEncoder(w).Encode(map[string]string{"error": msg})
		return
	}

	code := h.CodeStore.Generate(body.Email)

	if !h.MockMode {
		if err := h.sendEmailVerification(body.Email, code); err != nil {
			http.Error(w, fmt.Sprintf(`{"error":"Failed to send email: %s"}`, err.Error()), http.StatusInternalServerError)
			return
		}
	}

	resp := map[string]any{"success": true}
	if h.MockMode {
		resp["code"] = code
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func (h *AuthHandler) sendEmailVerification(toEmail, code string) error {
	subject := "ZhiZhi - Verification Code"
	body := fmt.Sprintf("Your verification code is: %s\n\nThis code expires in 5 minutes.\n\n-- ZhiZhi", code)

	smtpHost := os.Getenv("SMTP_HOST")
	smtpPort := os.Getenv("SMTP_PORT")
	smtpUser := os.Getenv("SMTP_USER")
	smtpPass := os.Getenv("SMTP_PASS")

	if smtpHost == "" || smtpUser == "" {
		return fmt.Errorf("SMTP not configured (set SMTP_HOST, SMTP_USER, SMTP_PASS)")
	}
	if smtpPort == "" {
		smtpPort = "587"
	}

	msg := fmt.Sprintf("From: %s\r\nTo: %s\r\nSubject: %s\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n%s",
		smtpUser, toEmail, subject, body)

	auth := smtp.PlainAuth("", smtpUser, smtpPass, smtpHost)
	return smtp.SendMail(smtpHost+":"+smtpPort, auth, smtpUser, []string{toEmail}, []byte(msg))
}

func (h *AuthHandler) findOrCreateUser(ctx context.Context, field, value, email, displayName string) (string, bool) {
	var userID string
	var initialized bool

	query := `SELECT u.id, COALESCE(p.initialized, false) FROM users u
	          LEFT JOIN user_profiles p ON u.id = p.user_id WHERE u.` + field + ` = $1`
	err := db.Pool.QueryRow(ctx, query, value).Scan(&userID, &initialized)
	if err == nil {
		return userID, initialized
	}

	// Also try by email if field is not email
	if field != "email" && email != "" {
		err = db.Pool.QueryRow(ctx,
			`SELECT u.id, COALESCE(p.initialized, false) FROM users u
			 LEFT JOIN user_profiles p ON u.id = p.user_id WHERE u.email = $1`, email).Scan(&userID, &initialized)
		if err == nil {
			// Link the new identity to existing user
			db.Pool.Exec(ctx, `UPDATE users SET `+field+` = $1 WHERE id = $2`, value, userID)
			return userID, initialized
		}
	}

	// Create new user
	insertQ := `INSERT INTO users (` + field
	insertArgs := []any{value}
	argIdx := 2

	if field != "email" && email != "" {
		insertQ += `, email`
		insertArgs = append(insertArgs, email)
		argIdx++
	}
	if displayName != "" {
		insertQ += `, display_name`
		insertArgs = append(insertArgs, displayName)
		argIdx++
	}

	insertQ += `) VALUES (`
	for i := range insertArgs {
		if i > 0 {
			insertQ += `, `
		}
		insertQ += `$` + itoa2(i+1)
	}
	insertQ += `) RETURNING id`

	err = db.Pool.QueryRow(ctx, insertQ, insertArgs...).Scan(&userID)
	if err != nil {
		return "", false
	}

	db.Pool.Exec(ctx, `INSERT INTO user_profiles (user_id) VALUES ($1)`, userID)
	return userID, false
}

func itoa2(n int) string {
	if n < 10 {
		return string(rune('0' + n))
	}
	return itoa2(n/10) + string(rune('0'+n%10))
}

func verifyAppleToken(token string) (appleID, email string, err error) {
	// Parse JWT claims without full verification for MVP.
	// Production should verify against Apple's public keys at https://appleid.apple.com/auth/keys
	parts := splitJWT(token)
	if parts == nil {
		return "", "", fmt.Errorf("invalid token format")
	}
	claims, err := decodeJWTClaims(parts[1])
	if err != nil {
		return "", "", err
	}
	sub, _ := claims["sub"].(string)
	em, _ := claims["email"].(string)
	if sub == "" {
		return "", "", fmt.Errorf("missing sub claim")
	}
	return sub, em, nil
}

func verifyGoogleToken(token string) (googleID, email string, err error) {
	// Parse JWT claims without full verification for MVP.
	// Production should verify against Google's public keys
	parts := splitJWT(token)
	if parts == nil {
		return "", "", fmt.Errorf("invalid token format")
	}
	claims, err := decodeJWTClaims(parts[1])
	if err != nil {
		return "", "", err
	}
	sub, _ := claims["sub"].(string)
	em, _ := claims["email"].(string)
	if sub == "" {
		return "", "", fmt.Errorf("missing sub claim")
	}
	return sub, em, nil
}

func splitJWT(token string) []string {
	parts := make([]string, 0, 3)
	start := 0
	count := 0
	for i, c := range token {
		if c == '.' {
			parts = append(parts, token[start:i])
			start = i + 1
			count++
		}
	}
	if count == 2 {
		parts = append(parts, token[start:])
		return parts
	}
	return nil
}

func decodeJWTClaims(payload string) (map[string]any, error) {
	decoded, err := base64URLDecode(payload)
	if err != nil {
		return nil, err
	}
	var claims map[string]any
	if err := json.Unmarshal(decoded, &claims); err != nil {
		return nil, err
	}
	return claims, nil
}

func base64URLDecode(s string) ([]byte, error) {
	for len(s)%4 != 0 {
		s += "="
	}
	return base64.URLEncoding.DecodeString(s)
}

// DeleteAccount permanently deletes the user and all associated data.
// Required by Apple App Store review guidelines.
func (h *AuthHandler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	ctx := context.Background()

	deleteQueries := []string{
		`DELETE FROM execution_logs WHERE task_id IN (SELECT id FROM tasks WHERE user_id = $1)`,
		`DELETE FROM sub_tasks WHERE task_id IN (SELECT id FROM tasks WHERE user_id = $1)`,
		`DELETE FROM memories WHERE user_id = $1`,
		`DELETE FROM task_items WHERE user_id = $1`,
		`DELETE FROM scheduled_jobs WHERE user_id = $1`,
		`DELETE FROM tasks WHERE user_id = $1`,
		`DELETE FROM sessions WHERE user_id = $1`,
		`DELETE FROM user_accounts WHERE user_id = $1`,
		`DELETE FROM push_tokens WHERE user_id = $1`,
		`DELETE FROM user_rules WHERE user_id = $1`,
		`DELETE FROM user_profiles WHERE user_id = $1`,
		`DELETE FROM users WHERE id = $1`,
	}

	for _, q := range deleteQueries {
		if _, err := db.Pool.Exec(ctx, q, userID); err != nil {
			http.Error(w, `{"error":"Failed to delete account data"}`, http.StatusInternalServerError)
			return
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"deleted": true})
}
