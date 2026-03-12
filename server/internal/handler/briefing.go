package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"time"

	"github.com/xiaozhong/command-center-server/internal/db"
	"github.com/xiaozhong/command-center-server/internal/middleware"
	"github.com/xiaozhong/command-center-server/internal/model"
)

type highlight struct {
	Task     briefTask `json:"task"`
	Priority int       `json:"priority"`
	Reason   string    `json:"reason"`
	Actions  []string  `json:"actions"`
}

type briefTask struct {
	ID            string          `json:"id"`
	InputText     *string         `json:"inputText"`
	Understanding *string         `json:"understanding"`
	Status        string          `json:"status"`
	IntentType    *string         `json:"intentType"`
	Result        json.RawMessage `json:"result,omitempty"`
	Error         *string         `json:"error,omitempty"`
	CreatedAt     time.Time       `json:"createdAt"`
	UpdatedAt     time.Time       `json:"updatedAt"`
}

func Briefing(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	ctx := context.Background()
	now := time.Now()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())

	rows, err := db.Pool.Query(ctx,
		`SELECT id, input_text, understanding, status, intent_type,
		        result, error, created_at, updated_at
		 FROM tasks WHERE user_id = $1
		   AND status NOT IN ('cancelled')
		   AND (status != 'completed' OR updated_at >= $2)
		 ORDER BY created_at DESC LIMIT 50`, userID, todayStart)
	if err != nil {
		http.Error(w, `{"error":"query failed"}`, http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var tasks []briefTask
	for rows.Next() {
		var t briefTask
		if err := rows.Scan(&t.ID, &t.InputText, &t.Understanding, &t.Status,
			&t.IntentType, &t.Result, &t.Error, &t.CreatedAt, &t.UpdatedAt); err != nil {
			continue
		}
		tasks = append(tasks, t)
	}

	var highlights []highlight
	restCount := 0
	todayCompleted := 0

	for _, t := range tasks {
		if t.Status == string(model.TaskStatusCompleted) {
			todayCompleted++
			continue
		}

		priority := 0
		reason := ""
		var actions []string

		switch model.TaskStatus(t.Status) {
		case model.TaskStatusWaitingConfirm:
			priority = 100
			reason = "needs_decision"
			actions = []string{"confirm", "cancel", "detail"}
		case model.TaskStatusFailed:
			priority = 80
			reason = "failed"
			actions = []string{"retry", "detail"}
		case model.TaskStatusExecuting, model.TaskStatusUnderstanding, model.TaskStatusCreated:
			priority = 10
			reason = "in_progress"
			actions = []string{"detail", "pause"}

			if t.Status == string(model.TaskStatusExecuting) && now.Sub(t.CreatedAt) > 24*time.Hour {
				priority = 60
				reason = "taking_long"
				actions = []string{"detail", "pause", "cancel"}
			}
		case model.TaskStatusPaused:
			priority = 40
			reason = "paused"
			actions = []string{"resume", "cancel", "detail"}
		}

		if priority > 0 {
			highlights = append(highlights, highlight{
				Task: t, Priority: priority, Reason: reason, Actions: actions,
			})
		}
	}

	sort.Slice(highlights, func(i, j int) bool {
		return highlights[i].Priority > highlights[j].Priority
	})

	top := highlights
	if len(top) > 3 {
		restCount = len(top) - 3
		top = top[:3]
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"highlights":      top,
		"rest_count":      restCount,
		"rest_summary":    fmt.Sprintf("%d", restCount),
		"today_completed": todayCompleted,
	})
}
