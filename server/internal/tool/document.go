package tool

import (
	"fmt"

	"github.com/xiaozhong/command-center-server/internal/ai"
)

func NewDocumentTool(claude *ai.ClaudeClient) *Definition {
	return &Definition{
		Name:        "generate_document",
		Description: "生成文档、方案、简报、清单等",
		Parameters: map[string]any{
			"type":           map[string]any{"type": "string", "description": "文档类型"},
			"title":          map[string]any{"type": "string", "description": "文档标题"},
			"content_prompt": map[string]any{"type": "string", "description": "文档内容要求"},
		},
		Execute: func(params map[string]any, ctx Context) Result {
			prompt, _ := params["content_prompt"].(string)
			docType, _ := params["type"].(string)
			title, _ := params["title"].(string)

			userMsg := fmt.Sprintf("类型：%s\n标题：%s\n要求：%s\n\n直接输出内容，简洁清晰。", docType, title, prompt)

			resp, err := claude.Call(
				"你是一个专业的文档撰写助手。直接输出高质量的内容。",
				[]ai.Message{{Role: "user", Content: userMsg}},
				nil, 2048,
			)
			if err != nil {
				return Result{Success: false, Error: err.Error()}
			}

			text := claude.GetTextResponse(resp)
			return Result{Success: true, Data: map[string]string{"title": title, "content": text}}
		},
	}
}
