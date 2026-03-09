package handler

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/xiaozhong/command-center-server/internal/db"
	"github.com/xiaozhong/command-center-server/internal/middleware"
	"github.com/xiaozhong/command-center-server/internal/model"
)

func GetProfile(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	ctx := context.Background()

	var p model.UserProfile
	err := db.Pool.QueryRow(ctx,
		`SELECT user_id, profile, initialized, updated_at FROM user_profiles WHERE user_id = $1`, userID).Scan(
		&p.UserID, &p.Profile, &p.Initialized, &p.UpdatedAt)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"profile": nil})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"profile": p})
}

func UpdateProfile(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	var body struct {
		Profile json.RawMessage `json:"profile"`
	}
	json.NewDecoder(r.Body).Decode(&body)

	db.Pool.Exec(context.Background(),
		`UPDATE user_profiles SET profile = $1, updated_at = NOW() WHERE user_id = $2`,
		body.Profile, userID)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"success": true})
}

func GetRules(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	rows, err := db.Pool.Query(context.Background(),
		`SELECT id, user_id, rule_text, rule_parsed, active, created_at
		 FROM user_rules WHERE user_id = $1 AND active = true`, userID)
	if err != nil {
		http.Error(w, `{"error":"Query failed"}`, http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var rules []model.UserRule
	for rows.Next() {
		var rule model.UserRule
		rows.Scan(&rule.ID, &rule.UserID, &rule.RuleText, &rule.RuleParsed, &rule.Active, &rule.CreatedAt)
		rules = append(rules, rule)
	}
	if rules == nil {
		rules = []model.UserRule{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"rules": rules})
}

func DeleteRule(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	ruleID := r.PathValue("id")

	db.Pool.Exec(context.Background(),
		`UPDATE user_rules SET active = false WHERE id = $1 AND user_id = $2`, ruleID, userID)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"success": true})
}
