package service

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"

	"github.com/xiaozhong/command-center-server/internal/ai"
	"github.com/xiaozhong/command-center-server/internal/db"
	"github.com/xiaozhong/command-center-server/internal/model"
	"github.com/xiaozhong/command-center-server/internal/ws"
)

type UnderstandingService struct {
	Claude *ai.ClaudeClient
	Hub    *ws.Hub
}

func (s *UnderstandingService) Understand(taskID string) (*model.UnderstandingResult, error) {
	ctx := context.Background()

	var userID, inputText string
	var sessionID *string
	err := db.Pool.QueryRow(ctx,
		`SELECT user_id, COALESCE(input_text, ''), session_id FROM tasks WHERE id = $1`, taskID).Scan(&userID, &inputText, &sessionID)
	if err != nil {
		return nil, fmt.Errorf("task not found: %w", err)
	}

	var profileJSON json.RawMessage
	db.Pool.QueryRow(ctx, `SELECT profile FROM user_profiles WHERE user_id = $1`, userID).Scan(&profileJSON)
	var profile map[string]any
	json.Unmarshal(profileJSON, &profile)

	ruleRows, _ := db.Pool.Query(ctx,
		`SELECT rule_text FROM user_rules WHERE user_id = $1 AND active = true`, userID)
	var rules []string
	for ruleRows.Next() {
		var r string
		ruleRows.Scan(&r)
		rules = append(rules, r)
	}
	ruleRows.Close()

	var activeTasks []struct{ Status, Understanding string }
	var history []struct{ Input, Understanding string }

	if sessionID != nil {
		atRows, _ := db.Pool.Query(ctx,
			`SELECT status, COALESCE(understanding, input_text, '') FROM tasks
			 WHERE session_id = $1 AND id != $2 AND status IN ('executing', 'waiting_confirm')
			 ORDER BY created_at DESC LIMIT 5`, *sessionID, taskID)
		for atRows.Next() {
			var s, u string
			atRows.Scan(&s, &u)
			activeTasks = append(activeTasks, struct{ Status, Understanding string }{s, u})
		}
		atRows.Close()

		hRows, _ := db.Pool.Query(ctx,
			`SELECT COALESCE(input_text, ''), COALESCE(understanding, '')
			 FROM tasks WHERE session_id = $1 AND id != $2 AND understanding IS NOT NULL
			 ORDER BY created_at DESC LIMIT 5`, *sessionID, taskID)
		for hRows.Next() {
			var inp, und string
			hRows.Scan(&inp, &und)
			history = append(history, struct{ Input, Understanding string }{inp, und})
		}
		hRows.Close()
	}

	var memories []string
	memRows, _ := db.Pool.Query(ctx,
		`SELECT content FROM memories WHERE user_id = $1 ORDER BY created_at DESC LIMIT 10`, userID)
	for memRows.Next() {
		var m string
		memRows.Scan(&m)
		memories = append(memories, m)
	}
	memRows.Close()

	userCtx := ai.UserContext{
		Profile:     profile,
		Rules:       rules,
		ActiveTasks: activeTasks,
		History:     history,
		Memories:    memories,
	}
	systemPrompt := ai.BuildUnderstandingPrompt(userCtx)

	s.Hub.Send(userID, model.PushEvent{
		Type:    "task_understanding",
		TaskID:  taskID,
		Message: "正在理解你的指令…",
	})

	resp, err := s.Claude.Call(systemPrompt, []ai.Message{{Role: "user", Content: inputText}}, nil, 4096)
	if err != nil {
		return nil, fmt.Errorf("claude call: %w", err)
	}

	text := s.Claude.GetTextResponse(resp)
	text = strings.TrimPrefix(text, "```json")
	text = strings.TrimPrefix(text, "```")
	text = strings.TrimSuffix(text, "```")
	text = strings.TrimSpace(text)

	var result model.UnderstandingResult
	if err := json.Unmarshal([]byte(text), &result); err != nil {
		slog.Warn("Failed to parse understanding result, using raw text", "err", err)
		result = model.UnderstandingResult{
			Understanding: text,
			ExecutionPlan: model.ExecutionPlan{
				Steps: []model.ExecutionStep{{Description: text}},
			},
			RiskLevel:  "low",
			IntentType: "task",
		}
	}

	// If Claude identified this as a follow-up to an existing task, link them
	if result.RelatedTaskID != nil && *result.RelatedTaskID != "" {
		db.Pool.Exec(ctx,
			`UPDATE tasks SET parent_task_id = $1 WHERE id = $2`,
			*result.RelatedTaskID, taskID)
		slog.Info("Task linked as follow-up", "taskId", taskID, "parentId", *result.RelatedTaskID)
	}

	// If intent is "rule", auto-save to user_rules
	if result.IntentType == "rule" && result.Understanding != "" {
		db.Pool.Exec(ctx,
			`INSERT INTO user_rules (user_id, rule_text) VALUES ($1, $2)`,
			userID, result.Understanding)
		slog.Info("Auto-saved rule", "userId", userID, "rule", result.Understanding)
	}

	nextStatus := "executing"
	if result.ExecutionPlan.RequiresConfirmation {
		nextStatus = "waiting_confirm"
	}

	planJSON, _ := json.Marshal(result.ExecutionPlan)
	db.Pool.Exec(ctx,
		`UPDATE tasks SET understanding = $1, execution_plan = $2, risk_level = $3,
		 intent_type = $4, status = $5, updated_at = NOW() WHERE id = $6`,
		result.Understanding, planJSON, result.RiskLevel, result.IntentType, nextStatus, taskID)

	s.Hub.Send(userID, model.PushEvent{
		Type:    "task_understanding",
		TaskID:  taskID,
		Message: result.Understanding,
		Task: &model.TaskBrief{
			ID:            taskID,
			InputText:     inputText,
			Understanding: result.Understanding,
			Status:        nextStatus,
			Steps:         result.ExecutionPlan.Steps,
		},
	})

	if nextStatus == "waiting_confirm" {
		msg := result.ExecutionPlan.ConfirmationMessage
		if msg == "" {
			msg = result.Understanding
		}
		s.Hub.Send(userID, model.PushEvent{
			Type:    "task_waiting_confirm",
			TaskID:  taskID,
			Message: msg,
			Task: &model.TaskBrief{
				ID:            taskID,
				InputText:     inputText,
				Understanding: result.Understanding,
				Status:        "waiting_confirm",
			},
		})
	}

	if sessionID != nil {
		go s.autoTitleSession(userID, *sessionID, inputText)
	}

	return &result, nil
}

func (s *UnderstandingService) autoTitleSession(userID, sessionID, inputText string) {
	ctx := context.Background()

	var currentTitle *string
	db.Pool.QueryRow(ctx, `SELECT title FROM sessions WHERE id = $1`, sessionID).Scan(&currentTitle)
	if currentTitle != nil && *currentTitle != "" {
		return
	}

	var taskCount int
	db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM tasks WHERE session_id = $1`, sessionID).Scan(&taskCount)
	if taskCount > 1 {
		return
	}

	title, err := s.Claude.CallSimple(
		"你是一个标题生成器。根据用户的指令，生成一个简洁的会话标题（5-8个字）。只输出标题本身，不要引号、标点或解释。",
		inputText, 50)
	if err != nil {
		slog.Warn("Auto title generation failed, using fallback", "err", err)
		title = inputText
	}

	title = strings.TrimSpace(title)
	title = strings.Trim(title, "\"「」『』")
	runes := []rune(title)
	if len(runes) > 15 {
		title = string(runes[:14]) + "…"
	}
	if title == "" {
		return
	}

	db.Pool.Exec(ctx,
		`UPDATE sessions SET title = $1, updated_at = NOW() WHERE id = $2 AND (title IS NULL OR title = '')`,
		title, sessionID)

	s.Hub.Send(userID, model.PushEvent{
		Type:      "session_updated",
		SessionID: sessionID,
		Title:     title,
	})

	slog.Info("Session auto-titled", "sessionID", sessionID, "title", title)
}
