package service

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"time"

	"github.com/xiaozhong/command-center-server/internal/ai"
	"github.com/xiaozhong/command-center-server/internal/db"
	"github.com/xiaozhong/command-center-server/internal/model"
	"github.com/xiaozhong/command-center-server/internal/tool"
	"github.com/xiaozhong/command-center-server/internal/ws"
)

const maxRounds = 10
const timeoutDuration = 60 * time.Second

type AgentRunner struct {
	Claude   *ai.ClaudeClient
	Registry *tool.Registry
	Hub      *ws.Hub
}

type RunConfig struct {
	UserID      string
	TaskID      string
	SubTaskID   string
	Description string
}

type RunResult struct {
	Output        string
	ToolCallCount int
}

func (r *AgentRunner) Run(cfg RunConfig) (*RunResult, error) {
	toolCtx := tool.Context{UserID: cfg.UserID, TaskID: cfg.TaskID, SubTaskID: cfg.SubTaskID}
	tools := r.Registry.ToAITools()
	isOpenRouter := os.Getenv("OPENROUTER_API_KEY") != ""

	messages := []ai.Message{{Role: "user", Content: cfg.Description}}
	toolCallCount := 0
	start := time.Now()

	for round := 0; round < maxRounds; round++ {
		if time.Since(start) > timeoutDuration {
			return nil, fmt.Errorf("agent execution timeout after %d rounds", round)
		}

		resp, err := r.Claude.Call(
			"你是一个执行管理任务的 AI Agent。使用提供的工具完成任务，完成后直接输出结果摘要。",
			messages, tools, 4096,
		)
		if err != nil {
			return nil, fmt.Errorf("claude call round %d: %w", round, err)
		}

		if resp.StopReason == "end_turn" {
			text := r.Claude.GetTextResponse(resp)
			return &RunResult{Output: text, ToolCallCount: toolCallCount}, nil
		}

		if resp.StopReason == "tool_use" {
			// Execute each tool call
			type toolCallResult struct {
				id     string
				name   string
				result tool.Result
			}
			var results []toolCallResult

			for _, block := range resp.Content {
				if block.Type != "tool_use" {
					continue
				}

				result := r.Registry.Execute(block.Name, block.Input, toolCtx)
				toolCallCount++

				logPayload, _ := json.Marshal(map[string]any{
					"tool": block.Name, "input": block.Input, "result": result,
				})
				db.Pool.Exec(context.Background(),
					`INSERT INTO execution_logs (task_id, sub_task_id, event_type, payload)
					 VALUES ($1, $2, 'tool_call', $3)`,
					cfg.TaskID, nilIfEmpty(cfg.SubTaskID), logPayload)

				r.Hub.Send(cfg.UserID, model.PushEvent{
					Type:    "task_progress",
					TaskID:  cfg.TaskID,
					Message: fmt.Sprintf("正在执行：%s", block.Name),
					Step:    cfg.SubTaskID,
				})

				results = append(results, toolCallResult{id: block.ID, name: block.Name, result: result})
			}

			if isOpenRouter {
				// OpenAI format: assistant message with tool_calls, then tool role messages
				var toolCalls []map[string]any
				for _, block := range resp.Content {
					if block.Type == "tool_use" {
						argsJSON, _ := json.Marshal(block.Input)
						toolCalls = append(toolCalls, map[string]any{
							"id":   block.ID,
							"type": "function",
							"function": map[string]any{
								"name":      block.Name,
								"arguments": string(argsJSON),
							},
						})
					}
				}

				assistantContent := ""
				for _, block := range resp.Content {
					if block.Type == "text" {
						assistantContent = block.Text
					}
				}

				messages = append(messages, ai.Message{
					Role: "assistant",
					Content: map[string]any{
						"content":    assistantContent,
						"tool_calls": toolCalls,
					},
				})

				for _, r := range results {
					resultJSON, _ := json.Marshal(r.result)
					messages = append(messages, ai.Message{
						Role: "tool",
						Content: map[string]any{
							"tool_call_id": r.id,
							"content":      string(resultJSON),
						},
					})
				}
			} else {
				// Anthropic native format
				messages = append(messages, ai.Message{Role: "assistant", Content: resp.Content})
				var toolResults []map[string]any
				for _, r := range results {
					resultJSON, _ := json.Marshal(r.result)
					toolResults = append(toolResults, map[string]any{
						"type":        "tool_result",
						"tool_use_id": r.id,
						"content":     string(resultJSON),
					})
				}
				messages = append(messages, ai.Message{Role: "user", Content: toolResults})
			}
		}
	}

	return nil, fmt.Errorf("agent exceeded maximum %d rounds", maxRounds)
}

func nilIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func init() {
	_ = slog.Default()
}
