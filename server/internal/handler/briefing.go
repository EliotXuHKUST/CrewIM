package handler

import (
	"context"
	"encoding/json"
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
	ID            string           `json:"id"`
	InputText     *string          `json:"inputText"`
	Understanding *string          `json:"understanding"`
	Status        string           `json:"status"`
	IntentType    *string          `json:"intentType"`
	Result        json.RawMessage  `json:"result,omitempty"`
	Error         *string          `json:"error,omitempty"`
	CreatedAt     time.Time        `json:"createdAt"`
	UpdatedAt     time.Time        `json:"updatedAt"`
}

func Briefing(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	ctx := context.Background()
	now := time.Now()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())

	rows, err := db.Pool.Query(ctx,
		`SELECT id, COALESCE(input_text,''), understanding, status, intent_type,
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
		var inputText string
		if err := rows.Scan(&inputText, &inputText, &t.Understanding, &t.Status,
			&t.IntentType, &t.Result, &t.Error, &t.CreatedAt, &t.UpdatedAt); err != nil {
			continue
		}
		rows.Scan(&t.ID, &inputText, &t.Understanding, &t.Status,
			&t.IntentType, &t.Result, &t.Error, &t.CreatedAt, &t.UpdatedAt)
		t.InputText = &inputText
		tasks = append(tasks, t)
	}

	// Re-query properly
	tasks = nil
	rows2, _ := db.Pool.Query(ctx,
		`SELECT id, input_text, understanding, status, intent_type,
		        result, error, created_at, updated_at
		 FROM tasks WHERE user_id = $1
		   AND status NOT IN ('cancelled')
		   AND (status != 'completed' OR updated_at >= $2)
		 ORDER BY created_at DESC LIMIT 50`, userID, todayStart)
	if rows2 != nil {
		defer rows2.Close()
		for rows2.Next() {
			var t briefTask
			rows2.Scan(&t.ID, &t.InputText, &t.Understanding, &t.Status,
				&t.IntentType, &t.Result, &t.Error, &t.CreatedAt, &t.UpdatedAt)
			tasks = append(tasks, t)
		}
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
			reason = "需要你拍板"
			actions = []string{"confirm", "cancel", "detail"}
		case model.TaskStatusFailed:
			priority = 80
			reason = "执行失败，需要处理"
			actions = []string{"retry", "detail"}
		case model.TaskStatusExecuting, model.TaskStatusUnderstanding, model.TaskStatusCreated:
			priority = 10
			reason = "正在进行"
			actions = []string{"detail"}

			if t.Status == string(model.TaskStatusExecuting) && now.Sub(t.CreatedAt) > 24*time.Hour {
				priority = 60
				reason = "执行时间较长，可能需要关注"
				actions = []string{"detail", "cancel"}
			}
		case model.TaskStatusPaused:
			priority = 40
			reason = "已暂停，等待恢复"
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

	restSummary := ""
	if restCount > 0 {
		restSummary = formatRestSummary(restCount)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"highlights":      top,
		"rest_count":      restCount,
		"rest_summary":    restSummary,
		"today_completed": todayCompleted,
	})
}

func formatRestSummary(count int) string {
	if count == 1 {
		return "另有 1 件事在正常推进"
	}
	return "另有 " + itoa(count) + " 件事在正常推进"
}

func itoa(n int) string {
	if n < 0 {
		return "-" + itoa(-n)
	}
	if n < 10 {
		return string(rune('0' + n))
	}
	return itoa(n/10) + string(rune('0'+n%10))
}
