package asr

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"
)

type Transcriber interface {
	Transcribe(audioPath string) (string, error)
}

type MockTranscriber struct{}

func (m *MockTranscriber) Transcribe(audioPath string) (string, error) {
	slog.Info("ASR mock transcribe", "path", audioPath)
	return "[语音转写] 这是一条测试语音指令", nil
}

type TencentASR struct {
	SecretID  string
	SecretKey string
}

func (t *TencentASR) Transcribe(audioPath string) (string, error) {
	data, err := os.ReadFile(audioPath)
	if err != nil {
		return "", fmt.Errorf("read audio: %w", err)
	}

	b64 := base64.StdEncoding.EncodeToString(data)

	reqBody := map[string]interface{}{
		"EngSerViceType": "16k_zh",
		"SourceType":     1,
		"VoiceFormat":    "m4a",
		"Data":           b64,
		"DataLen":        len(data),
	}
	bodyBytes, _ := json.Marshal(reqBody)

	timestamp := time.Now().Unix()
	date := time.Unix(timestamp, 0).UTC().Format("2006-01-02")

	host := "asr.tencentcloudapi.com"
	service := "asr"
	action := "SentenceRecognition"
	version := "2019-06-14"

	// TC3 signature
	hashedPayload := sha256Hex(bodyBytes)

	canonicalRequest := fmt.Sprintf("POST\n/\n\ncontent-type:application/json\nhost:%s\n\ncontent-type;host\n%s",
		host, hashedPayload)

	credentialScope := fmt.Sprintf("%s/%s/tc3_request", date, service)
	stringToSign := fmt.Sprintf("TC3-HMAC-SHA256\n%d\n%s\n%s",
		timestamp, credentialScope, sha256Hex([]byte(canonicalRequest)))

	secretDate := hmacSHA256([]byte("TC3"+t.SecretKey), []byte(date))
	secretService := hmacSHA256(secretDate, []byte(service))
	secretSigning := hmacSHA256(secretService, []byte("tc3_request"))
	signature := hex.EncodeToString(hmacSHA256(secretSigning, []byte(stringToSign)))

	auth := fmt.Sprintf("TC3-HMAC-SHA256 Credential=%s/%s, SignedHeaders=content-type;host, Signature=%s",
		t.SecretID, credentialScope, signature)

	req, _ := http.NewRequest("POST", "https://"+host, strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Host", host)
	req.Header.Set("Authorization", auth)
	req.Header.Set("X-TC-Action", action)
	req.Header.Set("X-TC-Version", version)
	req.Header.Set("X-TC-Timestamp", fmt.Sprintf("%d", timestamp))
	req.Header.Set("X-TC-Region", "ap-shanghai")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("tencent asr request: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)

	var result struct {
		Response struct {
			Result    string `json:"Result"`
			RequestId string `json:"RequestId"`
			Error     *struct {
				Code    string `json:"Code"`
				Message string `json:"Message"`
			} `json:"Error"`
		} `json:"Response"`
	}

	if err := json.Unmarshal(respBody, &result); err != nil {
		return "", fmt.Errorf("parse asr response: %w", err)
	}

	if result.Response.Error != nil {
		return "", fmt.Errorf("tencent asr error: %s - %s",
			result.Response.Error.Code, result.Response.Error.Message)
	}

	text := strings.TrimSpace(result.Response.Result)
	slog.Info("ASR transcribed", "text", text)
	return text, nil
}

func sha256Hex(data []byte) string {
	h := sha256.Sum256(data)
	return hex.EncodeToString(h[:])
}

func hmacSHA256(key, data []byte) []byte {
	mac := hmac.New(sha256.New, key)
	mac.Write(data)
	return mac.Sum(nil)
}

func NewTranscriber(provider, secretID, secretKey string) Transcriber {
	if provider == "tencent" && secretID != "" && secretKey != "" {
		return &TencentASR{SecretID: secretID, SecretKey: secretKey}
	}
	return &MockTranscriber{}
}
