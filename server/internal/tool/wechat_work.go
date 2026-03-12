package tool

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"

	"github.com/xiaozhong/command-center-server/internal/db"
)

func NewWeChatWorkTool() *Definition {
	return &Definition{
		Name:        "send_wechat_work",
		Description: "通过企业微信群机器人发送消息。需要用户在设置中配置了群机器人 Webhook URL。",
		Parameters: map[string]any{
			"content": map[string]any{"type": "string", "description": "消息内容（支持 markdown）"},
		},
		Execute: func(params map[string]any, ctx Context) Result {
			content, _ := params["content"].(string)
			if content == "" {
				return Result{Success: false, Error: "消息内容不能为空"}
			}

			webhookURL, err := getWebhookURL(ctx.UserID)
			if err != nil {
				return Result{Success: false, Error: fmt.Sprintf("未配置企业微信群机器人：%v", err)}
			}

			if err := postToWebhook(webhookURL, content); err != nil {
				slog.Error("WeChat Work webhook failed", "err", err)
				return Result{Success: false, Error: fmt.Sprintf("发送失败：%v", err)}
			}

			slog.Info("WeChat Work message sent", "userId", ctx.UserID)
			return Result{
				Success: true,
				Data:    map[string]string{"status": "已发送到企业微信群"},
			}
		},
	}
}

func getWebhookURL(userID string) (string, error) {
	var profileJSON json.RawMessage
	err := db.Pool.QueryRow(context.Background(),
		`SELECT profile FROM user_profiles WHERE user_id = $1`, userID).Scan(&profileJSON)
	if err != nil {
		return "", fmt.Errorf("profile not found")
	}

	var profile map[string]any
	if json.Unmarshal(profileJSON, &profile) != nil {
		return "", fmt.Errorf("invalid profile")
	}

	url, _ := profile["wechat_work_webhook"].(string)
	if url == "" {
		return "", fmt.Errorf("webhook URL not configured")
	}
	return url, nil
}

func postToWebhook(webhookURL, content string) error {
	payload := map[string]any{
		"msgtype": "markdown",
		"markdown": map[string]string{
			"content": content,
		},
	}
	data, _ := json.Marshal(payload)

	resp, err := http.Post(webhookURL, "application/json", bytes.NewReader(data))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("webhook returned %d", resp.StatusCode)
	}
	return nil
}
