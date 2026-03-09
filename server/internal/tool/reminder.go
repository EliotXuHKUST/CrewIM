package tool

import (
	"context"
	"encoding/json"
	"time"

	"github.com/xiaozhong/command-center-server/internal/db"
)

var SetReminder = &Definition{
	Name:        "set_reminder",
	Description: "设定提醒（定时或周期性）",
	Parameters: map[string]any{
		"message":   map[string]any{"type": "string", "description": "提醒内容"},
		"remind_at": map[string]any{"type": "string", "description": "提醒时间 ISO 格式"},
		"repeat":    map[string]any{"type": "string", "description": "重复规则 cron 表达式（可选）"},
	},
	Execute: func(params map[string]any, ctx Context) Result {
		message, _ := params["message"].(string)
		remindAtStr, _ := params["remind_at"].(string)
		repeat, _ := params["repeat"].(string)

		remindAt, err := time.Parse(time.RFC3339, remindAtStr)
		if err != nil {
			return Result{Success: false, Error: "invalid remind_at format"}
		}

		jobType := "once"
		if repeat != "" {
			jobType = "cron"
		}

		ctxJSON, _ := json.Marshal(map[string]string{"message": message, "taskId": ctx.TaskID})

		var id string
		err = db.Pool.QueryRow(context.Background(),
			`INSERT INTO scheduled_jobs (user_id, source_text, job_type, schedule, context, next_run_at)
			 VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
			ctx.UserID, message, jobType, repeat, ctxJSON, remindAt).Scan(&id)
		if err != nil {
			return Result{Success: false, Error: err.Error()}
		}
		return Result{Success: true, Data: map[string]string{"id": id, "nextRunAt": remindAt.Format(time.RFC3339)}}
	},
}
