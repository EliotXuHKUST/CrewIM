package service

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"

	"github.com/xiaozhong/command-center-server/internal/db"
	"github.com/xiaozhong/command-center-server/internal/model"
	"github.com/xiaozhong/command-center-server/internal/ws"
)

type Orchestrator struct {
	Runner *AgentRunner
	Hub    *ws.Hub
}

func (o *Orchestrator) Execute(taskID string) {
	ctx := context.Background()

	var userID, understanding string
	var planJSON json.RawMessage
	err := db.Pool.QueryRow(ctx,
		`SELECT user_id, COALESCE(understanding, ''), COALESCE(execution_plan, '{}')
		 FROM tasks WHERE id = $1`, taskID).Scan(&userID, &understanding, &planJSON)
	if err != nil {
		slog.Error("Task not found", "taskId", taskID, "err", err)
		return
	}

	var plan model.ExecutionPlan
	json.Unmarshal(planJSON, &plan)

	if len(plan.Steps) == 0 {
		o.failTask(taskID, userID, "No execution plan")
		return
	}

	var results []string

	for i, step := range plan.Steps {
		var subID string
		db.Pool.QueryRow(ctx,
			`INSERT INTO sub_tasks (task_id, step_index, description, status, started_at)
			 VALUES ($1, $2, $3, 'executing', NOW()) RETURNING id`,
			taskID, i, step.Description).Scan(&subID)

		result, err := o.Runner.Run(RunConfig{
			UserID:      userID,
			TaskID:      taskID,
			SubTaskID:   subID,
			Description: step.Description,
		})

		if err != nil {
			errJSON, _ := json.Marshal(map[string]string{"error": err.Error()})
			db.Pool.Exec(ctx,
				`UPDATE sub_tasks SET status = 'failed', result = $1, completed_at = NOW() WHERE id = $2`,
				errJSON, subID)
			o.failTask(taskID, userID, fmt.Sprintf("Step %d failed: %s", i+1, err.Error()))
			return
		}

		resultJSON, _ := json.Marshal(map[string]any{"output": result.Output, "toolCalls": result.ToolCallCount})
		db.Pool.Exec(ctx,
			`UPDATE sub_tasks SET status = 'completed', result = $1, completed_at = NOW() WHERE id = $2`,
			resultJSON, subID)

		results = append(results, result.Output)
	}

	combined := strings.Join(results, "\n\n")
	resultJSON, _ := json.Marshal(map[string]string{"title": understanding, "body": combined})

	db.Pool.Exec(ctx,
		`UPDATE tasks SET status = 'completed', result = $1, updated_at = NOW() WHERE id = $2`,
		resultJSON, taskID)

	o.Hub.Send(userID, model.PushEvent{
		Type:   "task_completed",
		TaskID: taskID,
		Result: &model.ResultCard{Title: understanding, Body: combined},
		Task: &model.TaskBrief{
			ID:            taskID,
			Understanding: understanding,
			Status:        "completed",
		},
	})
}

func (o *Orchestrator) failTask(taskID, userID, reason string) {
	db.Pool.Exec(context.Background(),
		`UPDATE tasks SET status = 'failed', error = $1, updated_at = NOW() WHERE id = $2`,
		reason, taskID)

	o.Hub.Send(userID, model.PushEvent{
		Type:   "task_failed",
		TaskID: taskID,
		Reason: reason,
		Task: &model.TaskBrief{
			ID:     taskID,
			Status: "failed",
		},
	})
}
