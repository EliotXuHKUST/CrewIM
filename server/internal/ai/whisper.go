package ai

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
)

type WhisperClient struct {
	apiKey string
	apiURL string
}

func NewWhisperClient(apiKey, apiURL string) *WhisperClient {
	if apiURL == "" {
		apiURL = "https://api.openai.com/v1/audio/transcriptions"
	}
	return &WhisperClient{apiKey: apiKey, apiURL: apiURL}
}

func (w *WhisperClient) Transcribe(audioPath string) (string, error) {
	if w.apiKey == "" {
		return fmt.Sprintf("[Mock transcription of %s]", filepath.Base(audioPath)), nil
	}

	file, err := os.Open(audioPath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	var buf bytes.Buffer
	writer := multipart.NewWriter(&buf)

	part, err := writer.CreateFormFile("file", filepath.Base(audioPath))
	if err != nil {
		return "", err
	}
	if _, err := io.Copy(part, file); err != nil {
		return "", err
	}
	writer.WriteField("model", "whisper-1")
	writer.WriteField("language", "zh")
	writer.Close()

	req, err := http.NewRequest("POST", w.apiURL, &buf)
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+w.apiKey)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("whisper api: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("whisper error %d: %s", resp.StatusCode, string(body))
	}

	var result struct{ Text string }
	json.Unmarshal(body, &result)
	return result.Text, nil
}
