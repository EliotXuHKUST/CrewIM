package tool

import (
	"context"
	"strings"

	"github.com/xiaozhong/command-center-server/internal/db"
)

var StoreMemory = &Definition{
	Name:        "store_memory",
	Description: "存储关键信息到长期记忆",
	Parameters: map[string]any{
		"content":     map[string]any{"type": "string", "description": "要存储的信息"},
		"memory_type": map[string]any{"type": "string", "description": "类型 key_info/decision/preference"},
	},
	Execute: func(params map[string]any, ctx Context) Result {
		content, _ := params["content"].(string)
		memType, _ := params["memory_type"].(string)
		if memType == "" {
			memType = "key_info"
		}

		var id string
		err := db.Pool.QueryRow(context.Background(),
			`INSERT INTO memories (user_id, task_id, content, memory_type) VALUES ($1, $2, $3, $4) RETURNING id`,
			ctx.UserID, ctx.TaskID, content, memType).Scan(&id)
		if err != nil {
			return Result{Success: false, Error: err.Error()}
		}
		return Result{Success: true, Data: map[string]string{"id": id}}
	},
}

var SearchMemory = &Definition{
	Name:        "search_memory",
	Description: "搜索历史记忆中的相关信息",
	Parameters: map[string]any{
		"query": map[string]any{"type": "string", "description": "搜索关键词"},
	},
	Execute: func(params map[string]any, ctx Context) Result {
		query, _ := params["query"].(string)

		rows, err := db.Pool.Query(context.Background(),
			`SELECT id, content, memory_type, created_at FROM memories
			 WHERE user_id = $1 ORDER BY created_at DESC LIMIT 20`, ctx.UserID)
		if err != nil {
			return Result{Success: false, Error: err.Error()}
		}
		defer rows.Close()

		var results []map[string]string
		q := strings.ToLower(query)
		for rows.Next() {
			var id, content, memType, createdAt string
			rows.Scan(&id, &content, &memType, &createdAt)
			if strings.Contains(strings.ToLower(content), q) {
				results = append(results, map[string]string{
					"id": id, "content": content, "type": memType,
				})
			}
		}
		return Result{Success: true, Data: results}
	},
}
