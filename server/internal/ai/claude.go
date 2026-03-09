package ai

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
)

type ClaudeClient struct {
	apiKey       string
	model        string
	baseURL      string
	isOpenRouter bool

	// Anthropic direct fallback
	anthropicKey string
}

func NewClaudeClient(apiKey string) *ClaudeClient {
	orKey := os.Getenv("OPENROUTER_API_KEY")
	anKey := os.Getenv("ANTHROPIC_API_KEY")

	if orKey != "" {
		return &ClaudeClient{
			apiKey:       orKey,
			model:        "anthropic/claude-sonnet-4",
			baseURL:      "https://openrouter.ai/api/v1/chat/completions",
			isOpenRouter: true,
			anthropicKey: anKey,
		}
	}
	if anKey != "" {
		return &ClaudeClient{
			apiKey:       anKey,
			model:        "claude-sonnet-4-20250514",
			baseURL:      "https://api.anthropic.com/v1/messages",
			anthropicKey: anKey,
		}
	}
	if apiKey != "" {
		return &ClaudeClient{
			apiKey:  apiKey,
			model:   "claude-sonnet-4-20250514",
			baseURL: "https://api.anthropic.com/v1/messages",
		}
	}
	slog.Warn("No AI API key configured, LLM calls will fail")
	return &ClaudeClient{
		model:   "claude-sonnet-4-20250514",
		baseURL: "https://api.anthropic.com/v1/messages",
	}
}

type Message struct {
	Role    string `json:"role"`
	Content any    `json:"content"`
}

type Tool struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	InputSchema map[string]any `json:"input_schema"`
}

type ContentBlock struct {
	Type  string         `json:"type"`
	Text  string         `json:"text,omitempty"`
	ID    string         `json:"id,omitempty"`
	Name  string         `json:"name,omitempty"`
	Input map[string]any `json:"input,omitempty"`
}

type Response struct {
	ID         string         `json:"id"`
	Content    []ContentBlock `json:"content"`
	StopReason string         `json:"stop_reason"`
}

func (c *ClaudeClient) Call(system string, messages []Message, tools []Tool, maxTokens int) (*Response, error) {
	if maxTokens == 0 {
		maxTokens = 4096
	}

	if c.isOpenRouter {
		resp, err := c.callOpenRouter(system, messages, tools, maxTokens)
		if err != nil && c.anthropicKey != "" {
			slog.Warn("OpenRouter failed, falling back to Anthropic direct", "err", err)
			return c.callAnthropicDirect(c.anthropicKey, system, messages, tools, maxTokens)
		}
		return resp, err
	}
	return c.callAnthropic(system, messages, tools, maxTokens)
}

// CallSimple is a convenience method for quick single-turn text generation.
func (c *ClaudeClient) CallSimple(system, userMessage string, maxTokens int) (string, error) {
	resp, err := c.Call(system, []Message{{Role: "user", Content: userMessage}}, nil, maxTokens)
	if err != nil {
		return "", err
	}
	return c.GetTextResponse(resp), nil
}

func (c *ClaudeClient) callAnthropic(system string, messages []Message, tools []Tool, maxTokens int) (*Response, error) {
	return c.callAnthropicDirect(c.apiKey, system, messages, tools, maxTokens)
}

func (c *ClaudeClient) callAnthropicDirect(key, system string, messages []Message, tools []Tool, maxTokens int) (*Response, error) {
	if key == "" {
		return nil, fmt.Errorf("no Anthropic API key configured")
	}

	reqBody := map[string]any{
		"model":      "claude-sonnet-4-20250514",
		"max_tokens": maxTokens,
		"system":     system,
		"messages":   messages,
	}
	if len(tools) > 0 {
		reqBody["tools"] = tools
	}

	body, _ := json.Marshal(reqBody)
	req, _ := http.NewRequest("POST", "https://api.anthropic.com/v1/messages", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-api-key", key)
	req.Header.Set("anthropic-version", "2023-06-01")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("anthropic api: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("anthropic error %d: %s", resp.StatusCode, string(respBody))
	}

	var result Response
	json.Unmarshal(respBody, &result)
	return &result, nil
}

func (c *ClaudeClient) callOpenRouter(system string, messages []Message, tools []Tool, maxTokens int) (*Response, error) {
	orMessages := []map[string]any{
		{"role": "system", "content": system},
	}
	for _, m := range messages {
		msg := map[string]any{"role": m.Role}

		switch v := m.Content.(type) {
		case string:
			msg["content"] = v
		case map[string]any:
			if m.Role == "assistant" {
				if content, ok := v["content"]; ok {
					msg["content"] = content
				}
				if tc, ok := v["tool_calls"]; ok {
					msg["tool_calls"] = tc
				}
			} else if m.Role == "tool" {
				if tcID, ok := v["tool_call_id"]; ok {
					msg["tool_call_id"] = tcID
				}
				if content, ok := v["content"]; ok {
					msg["content"] = content
				}
			} else {
				msg["content"] = v
			}
		default:
			jsonBytes, _ := json.Marshal(v)
			msg["content"] = string(jsonBytes)
		}

		orMessages = append(orMessages, msg)
	}

	reqBody := map[string]any{
		"model":      c.model,
		"max_tokens": maxTokens,
		"messages":   orMessages,
	}

	if len(tools) > 0 {
		orTools := make([]map[string]any, len(tools))
		for i, t := range tools {
			orTools[i] = map[string]any{
				"type": "function",
				"function": map[string]any{
					"name":        t.Name,
					"description": t.Description,
					"parameters":  t.InputSchema,
				},
			}
		}
		reqBody["tools"] = orTools
	}

	body, _ := json.Marshal(reqBody)
	req, _ := http.NewRequest("POST", c.baseURL, bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.apiKey)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("openrouter api: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("openrouter error %d: %s", resp.StatusCode, string(respBody))
	}

	var orResp struct {
		ID      string `json:"id"`
		Choices []struct {
			Message struct {
				Role      string `json:"role"`
				Content   string `json:"content"`
				ToolCalls []struct {
					ID       string `json:"id"`
					Type     string `json:"type"`
					Function struct {
						Name      string `json:"name"`
						Arguments string `json:"arguments"`
					} `json:"function"`
				} `json:"tool_calls"`
			} `json:"message"`
			FinishReason string `json:"finish_reason"`
		} `json:"choices"`
	}

	if err := json.Unmarshal(respBody, &orResp); err != nil {
		return nil, fmt.Errorf("parse openrouter response: %w", err)
	}

	if len(orResp.Choices) == 0 {
		return nil, fmt.Errorf("openrouter: no choices in response")
	}

	choice := orResp.Choices[0]
	result := &Response{ID: orResp.ID}

	if choice.Message.Content != "" {
		result.Content = append(result.Content, ContentBlock{Type: "text", Text: choice.Message.Content})
	}

	for _, tc := range choice.Message.ToolCalls {
		var input map[string]any
		json.Unmarshal([]byte(tc.Function.Arguments), &input)
		result.Content = append(result.Content, ContentBlock{
			Type:  "tool_use",
			ID:    tc.ID,
			Name:  tc.Function.Name,
			Input: input,
		})
	}

	switch choice.FinishReason {
	case "tool_calls":
		result.StopReason = "tool_use"
	default:
		result.StopReason = "end_turn"
	}

	return result, nil
}

func (c *ClaudeClient) GetTextResponse(resp *Response) string {
	for _, block := range resp.Content {
		if block.Type == "text" {
			return block.Text
		}
	}
	return ""
}
