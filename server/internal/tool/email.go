package tool

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net"
	"net/smtp"
	"strconv"
	"strings"

	"github.com/xiaozhong/command-center-server/internal/crypto"
	"github.com/xiaozhong/command-center-server/internal/db"
)

type smtpCredentials struct {
	Host     string `json:"smtp_host"`
	Port     string `json:"smtp_port"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

func NewEmailTool(encryptKey string) *Definition {
	return &Definition{
		Name:        "send_email",
		Description: "使用用户绑定的邮箱发送邮件。需要用户在设置中配置了邮箱 SMTP 信息。",
		Parameters: map[string]any{
			"to":      map[string]any{"type": "string", "description": "收件人邮箱地址，多个用逗号分隔"},
			"subject": map[string]any{"type": "string", "description": "邮件主题"},
			"body":    map[string]any{"type": "string", "description": "邮件正文"},
			"cc":      map[string]any{"type": "string", "description": "抄送地址，可选"},
		},
		Execute: func(params map[string]any, ctx Context) Result {
			to, _ := params["to"].(string)
			subject, _ := params["subject"].(string)
			body, _ := params["body"].(string)
			cc, _ := params["cc"].(string)

			if to == "" || subject == "" {
				return Result{Success: false, Error: "收件人和主题不能为空"}
			}

			creds, err := loadEmailCredentials(ctx.UserID, encryptKey)
			if err != nil {
				return Result{Success: false, Error: fmt.Sprintf("未找到邮箱配置：%v", err)}
			}

			if err := sendSMTP(creds, to, cc, subject, body); err != nil {
				slog.Error("Email send failed", "err", err, "to", to)
				return Result{Success: false, Error: fmt.Sprintf("发送失败：%v", err)}
			}

			slog.Info("Email sent", "from", creds.Email, "to", to, "subject", subject)
			return Result{
				Success: true,
				Data: map[string]string{
					"from":    creds.Email,
					"to":      to,
					"subject": subject,
					"status":  "已发送",
				},
			}
		},
	}
}

func loadEmailCredentials(userID, encryptKey string) (*smtpCredentials, error) {
	var encData string
	err := db.Pool.QueryRow(context.Background(),
		`SELECT credentials_enc FROM user_accounts
		 WHERE user_id = $1 AND platform = 'email' LIMIT 1`, userID).Scan(&encData)
	if err != nil {
		return nil, fmt.Errorf("no email account bound")
	}

	plaintext, err := crypto.Decrypt(encData, encryptKey)
	if err != nil {
		return nil, fmt.Errorf("decrypt credentials: %w", err)
	}

	var creds smtpCredentials
	if err := json.Unmarshal([]byte(plaintext), &creds); err != nil {
		return nil, fmt.Errorf("parse credentials: %w", err)
	}

	if creds.Host == "" || creds.Email == "" || creds.Password == "" {
		return nil, fmt.Errorf("incomplete SMTP configuration")
	}
	if creds.Port == "" {
		creds.Port = "465"
	}

	return &creds, nil
}

func sendSMTP(creds *smtpCredentials, to, cc, subject, body string) error {
	recipients := parseAddresses(to)
	if cc != "" {
		recipients = append(recipients, parseAddresses(cc)...)
	}

	headers := fmt.Sprintf("From: %s\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n",
		creds.Email, to, subject)
	if cc != "" {
		headers += fmt.Sprintf("Cc: %s\r\n", cc)
	}
	msg := []byte(headers + "\r\n" + body)

	addr := net.JoinHostPort(creds.Host, creds.Port)
	auth := smtp.PlainAuth("", creds.Email, creds.Password, creds.Host)

	port, _ := strconv.Atoi(creds.Port)
	if port == 587 || port == 25 {
		return smtp.SendMail(addr, auth, creds.Email, recipients, msg)
	}

	// Port 465 uses implicit TLS; Go's smtp.SendMail doesn't support it directly.
	// For now, try standard SendMail which works with STARTTLS on 587.
	// TODO: add crypto/tls dial for port 465
	return smtp.SendMail(addr, auth, creds.Email, recipients, msg)
}

func parseAddresses(s string) []string {
	parts := strings.Split(s, ",")
	var result []string
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			result = append(result, p)
		}
	}
	return result
}
