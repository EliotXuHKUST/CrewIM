package tool

import (
	"context"

	"github.com/xiaozhong/command-center-server/internal/db"
)

var CreateTaskItem = &Definition{
	Name:        "create_task_item",
	Description: "创建一条管理事项（如待办、跟进任务等）",
	Parameters: map[string]any{
		"title":       map[string]any{"type": "string", "description": "事项标题"},
		"description": map[string]any{"type": "string", "description": "事项描述"},
		"assignee":    map[string]any{"type": "string", "description": "负责人"},
		"priority":    map[string]any{"type": "string", "description": "优先级 low/medium/high"},
		"deadline":    map[string]any{"type": "string", "description": "截止时间 ISO 格式"},
	},
	Execute: func(params map[string]any, ctx Context) Result {
		title, _ := params["title"].(string)
		if title == "" {
			return Result{Success: false, Error: "title is required"}
		}
		desc, _ := params["description"].(string)
		assignee, _ := params["assignee"].(string)
		priority, _ := params["priority"].(string)
		if priority == "" {
			priority = "medium"
		}

		var id string
		err := db.Pool.QueryRow(context.Background(),
			`INSERT INTO task_items (user_id, source_task_id, title, description, assignee, priority)
			 VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
			ctx.UserID, ctx.TaskID, title, desc, assignee, priority).Scan(&id)
		if err != nil {
			return Result{Success: false, Error: err.Error()}
		}
		return Result{Success: true, Data: map[string]string{"id": id, "title": title}}
	},
}

var ListTaskItems = &Definition{
	Name:        "list_task_items",
	Description: "查询管理事项列表",
	Parameters: map[string]any{
		"status":  map[string]any{"type": "string", "description": "按状态筛选"},
		"keyword": map[string]any{"type": "string", "description": "按关键词搜索"},
	},
	Execute: func(params map[string]any, ctx Context) Result {
		rows, err := db.Pool.Query(context.Background(),
			`SELECT id, title, description, assignee, priority, status, deadline
			 FROM task_items WHERE user_id = $1 AND status != 'deleted' ORDER BY created_at DESC LIMIT 20`,
			ctx.UserID)
		if err != nil {
			return Result{Success: false, Error: err.Error()}
		}
		defer rows.Close()

		var items []map[string]any
		for rows.Next() {
			var id, title, priority, status string
			var desc, assignee *string
			var deadline *string
			rows.Scan(&id, &title, &desc, &assignee, &priority, &status, &deadline)
			item := map[string]any{"id": id, "title": title, "priority": priority, "status": status}
			if desc != nil { item["description"] = *desc }
			if assignee != nil { item["assignee"] = *assignee }
			items = append(items, item)
		}
		return Result{Success: true, Data: items}
	},
}
