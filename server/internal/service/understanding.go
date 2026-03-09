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

	rows, _ := db.Pool.Query(ctx,
		`SELECT rule_text FROM user_rules WHERE user_id = $1 AND active = true`, userID)
	var rules []string
	for rows.Next() {
		var r string
		rows.Scan(&r)
		rules = append(rules, r)
	}
	rows.Close()

	userCtx := ai.UserContext{Profile: profile, Rules: rules}
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
	})

	if nextStatus == "waiting_confirm" {
		msg := result.ExecutionPlan.ConfirmationMessage
		if msg == "" {
			msg = result.Understanding
		}
		s.Hub.Send(userID, model.PushEvent{
			Type:    "task_confirmation_needed",
			TaskID:  taskID,
			Message: msg,
		})
	}

	if sessionID != nil {
		go s.autoTitleSession(*sessionID, inputText)
	}

	return &result, nil
}

func (s *UnderstandingService) autoTitleSession(sessionID, inputText string) {
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
		slog.Warn("Auto title generation failed", "err", err)
		return
	}

	title = strings.TrimSpace(title)
	title = strings.Trim(title, "\"「」『』")
	if len([]rune(title)) > 15 {
		title = string([]rune(title)[:15])
	}
	if title == "" {
		return
	}

	db.Pool.Exec(ctx,
		`UPDATE sessions SET title = $1, updated_at = NOW() WHERE id = $2 AND (title IS NULL OR title = '')`,
		title, sessionID)

	slog.Info("Session auto-titled", "sessionID", sessionID, "title", title)
}
