package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/jackc/pgx/v5"
	"github.com/xiaozhong/command-center-server/internal/db"
	"github.com/xiaozhong/command-center-server/internal/middleware"
	"github.com/xiaozhong/command-center-server/internal/model"
	"github.com/xiaozhong/command-center-server/internal/ws"
)

type TaskHandler struct {
	Hub   *ws.Hub
	Queue Enqueuer
}

func (h *TaskHandler) ListTasks(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	status := r.URL.Query().Get("status")
	sessionID := r.URL.Query().Get("session_id")
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}
	offset := (page - 1) * limit

	ctx := context.Background()
	query := `SELECT id, user_id, input_text, understanding, status, created_at, updated_at
	          FROM tasks WHERE user_id = $1`
	args := []any{userID}
	argIdx := 2

	if sessionID != "" {
		query += ` AND session_id = $` + strconv.Itoa(argIdx)
		args = append(args, sessionID)
		argIdx++
	}
	if status != "" {
		query += ` AND status = $` + strconv.Itoa(argIdx)
		args = append(args, status)
		argIdx++
	}
	query += ` ORDER BY created_at DESC LIMIT ` + strconv.Itoa(limit) + ` OFFSET ` + strconv.Itoa(offset)

	rows, err := db.Pool.Query(ctx, query, args...)
	if err != nil {
		http.Error(w, `{"error":"Query failed"}`, http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var tasks []model.Task
	for rows.Next() {
		var t model.Task
		rows.Scan(&t.ID, &t.UserID, &t.InputText, &t.Understanding, &t.Status, &t.CreatedAt, &t.UpdatedAt)
		tasks = append(tasks, t)
	}
	if tasks == nil {
		tasks = []model.Task{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"tasks": tasks, "page": page, "limit": limit})
}

func (h *TaskHandler) GetTask(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	taskID := r.PathValue("id")
	ctx := context.Background()

	var t model.Task
	err := db.Pool.QueryRow(ctx,
		`SELECT id, user_id, parent_task_id, input_text, input_audio_url, understanding,
		        execution_plan, risk_level, intent_type, status, result, error, created_at, updated_at
		 FROM tasks WHERE id = $1 AND user_id = $2`, taskID, userID).Scan(
		&t.ID, &t.UserID, &t.ParentTaskID, &t.InputText, &t.InputAudioURL, &t.Understanding,
		&t.ExecutionPlan, &t.RiskLevel, &t.IntentType, &t.Status, &t.Result, &t.Error, &t.CreatedAt, &t.UpdatedAt)

	if err == pgx.ErrNoRows {
		http.Error(w, `{"error":"Task not found"}`, http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, `{"error":"Query failed"}`, http.StatusInternalServerError)
		return
	}

	subRows, _ := db.Pool.Query(ctx,
		`SELECT id, task_id, step_index, description, status, result, started_at, completed_at
		 FROM sub_tasks WHERE task_id = $1 ORDER BY step_index`, taskID)
	defer subRows.Close()

	var subs []model.SubTask
	for subRows.Next() {
		var s model.SubTask
		subRows.Scan(&s.ID, &s.TaskID, &s.StepIndex, &s.Description, &s.Status, &s.Result, &s.StartedAt, &s.CompletedAt)
		subs = append(subs, s)
	}
	if subs == nil {
		subs = []model.SubTask{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"task": t, "subTasks": subs})
}

func (h *TaskHandler) ConfirmTask(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	taskID := r.PathValue("id")
	ctx := context.Background()

	var status string
	err := db.Pool.QueryRow(ctx, `SELECT status FROM tasks WHERE id = $1 AND user_id = $2`, taskID, userID).Scan(&status)
	if err != nil || status != "waiting_confirm" {
		http.Error(w, `{"error":"Task is not waiting for confirmation"}`, http.StatusBadRequest)
		return
	}

	db.Pool.Exec(ctx, `UPDATE tasks SET status = 'executing', updated_at = NOW() WHERE id = $1`, taskID)
	if h.Queue != nil {
		h.Queue.EnqueueExecute(taskID)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"taskId": taskID, "status": "executing"})
}

func (h *TaskHandler) CancelTask(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	taskID := r.PathValue("id")
	ctx := context.Background()

	var status string
	err := db.Pool.QueryRow(ctx, `SELECT status FROM tasks WHERE id = $1 AND user_id = $2`, taskID, userID).Scan(&status)
	if err != nil {
		http.Error(w, `{"error":"Task not found"}`, http.StatusNotFound)
		return
	}

	cancellable := map[string]bool{"created": true, "understanding": true, "waiting_confirm": true, "executing": true}
	if !cancellable[status] {
		http.Error(w, `{"error":"Task cannot be cancelled"}`, http.StatusBadRequest)
		return
	}

	db.Pool.Exec(ctx, `UPDATE tasks SET status = 'cancelled', updated_at = NOW() WHERE id = $1`, taskID)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"taskId": taskID, "status": "cancelled"})
}

func (h *TaskHandler) RetryTask(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	taskID := r.PathValue("id")
	ctx := context.Background()

	var status string
	err := db.Pool.QueryRow(ctx, `SELECT status FROM tasks WHERE id = $1 AND user_id = $2`, taskID, userID).Scan(&status)
	if err != nil || status != "failed" {
		http.Error(w, `{"error":"Only failed tasks can be retried"}`, http.StatusBadRequest)
		return
	}

	db.Pool.Exec(ctx, `UPDATE tasks SET status = 'created', error = NULL, updated_at = NOW() WHERE id = $1`, taskID)
	if h.Queue != nil {
		h.Queue.EnqueueUnderstand(taskID)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"taskId": taskID, "status": "created"})
}

func (h *TaskHandler) PauseTask(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	taskID := r.PathValue("id")
	ctx := context.Background()

	var status string
	err := db.Pool.QueryRow(ctx, `SELECT status FROM tasks WHERE id = $1 AND user_id = $2`, taskID, userID).Scan(&status)
	if err != nil {
		http.Error(w, `{"error":"Task not found"}`, http.StatusNotFound)
		return
	}
	if status != "executing" && status != "understanding" {
		http.Error(w, `{"error":"Only executing tasks can be paused"}`, http.StatusBadRequest)
		return
	}

	db.Pool.Exec(ctx, `UPDATE tasks SET status = 'paused', updated_at = NOW() WHERE id = $1`, taskID)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"taskId": taskID, "status": "paused"})
}

func (h *TaskHandler) ResumeTask(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	taskID := r.PathValue("id")
	ctx := context.Background()

	var status string
	err := db.Pool.QueryRow(ctx, `SELECT status FROM tasks WHERE id = $1 AND user_id = $2`, taskID, userID).Scan(&status)
	if err != nil || status != "paused" {
		http.Error(w, `{"error":"Task is not paused"}`, http.StatusBadRequest)
		return
	}

	db.Pool.Exec(ctx, `UPDATE tasks SET status = 'executing', updated_at = NOW() WHERE id = $1`, taskID)
	if h.Queue != nil {
		h.Queue.EnqueueExecute(taskID)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"taskId": taskID, "status": "executing"})
}

func (h *TaskHandler) BatchConfirm(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	var body struct {
		TaskIDs []string `json:"task_ids"`
	}
	json.NewDecoder(r.Body).Decode(&body)
	if len(body.TaskIDs) == 0 {
		http.Error(w, `{"error":"No task IDs provided"}`, http.StatusBadRequest)
		return
	}

	ctx := context.Background()
	confirmed := []string{}

	for _, taskID := range body.TaskIDs {
		var status string
		err := db.Pool.QueryRow(ctx,
			`SELECT status FROM tasks WHERE id = $1 AND user_id = $2`, taskID, userID).Scan(&status)
		if err != nil || status != "waiting_confirm" {
			continue
		}
		db.Pool.Exec(ctx, `UPDATE tasks SET status = 'executing', updated_at = NOW() WHERE id = $1`, taskID)
		if h.Queue != nil {
			h.Queue.EnqueueExecute(taskID)
		}
		confirmed = append(confirmed, taskID)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"confirmed": confirmed, "count": len(confirmed)})
}
