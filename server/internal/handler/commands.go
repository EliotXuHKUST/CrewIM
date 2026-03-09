package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"github.com/xiaozhong/command-center-server/internal/asr"
	"github.com/xiaozhong/command-center-server/internal/db"
	"github.com/xiaozhong/command-center-server/internal/middleware"
	"github.com/xiaozhong/command-center-server/internal/model"
	"github.com/xiaozhong/command-center-server/internal/openclaw"
	"github.com/xiaozhong/command-center-server/internal/service"
	"github.com/xiaozhong/command-center-server/internal/ws"
)

type Enqueuer interface {
	EnqueueUnderstand(taskID string)
	EnqueueExecute(taskID string)
}

type CommandHandler struct {
	Hub            *ws.Hub
	Queue          Enqueuer
	OpenClawClient *openclaw.Client
	ASR            asr.Transcriber
	UploadDir      string
}

func (h *CommandHandler) CreateCommand(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	var text, parentTaskID, sessionID *string
	var audioURL *string
	var imageURLs []string
	ct := r.Header.Get("Content-Type")

	if len(ct) > 19 && ct[:19] == "multipart/form-data" {
		r.ParseMultipartForm(20 << 20) // 20MB

		if v := r.FormValue("text"); v != "" {
			text = &v
		}
		if v := r.FormValue("parent_task_id"); v != "" {
			parentTaskID = &v
		}
		if v := r.FormValue("session_id"); v != "" {
			sessionID = &v
		}

		// Handle audio file
		audioFile, audioHeader, err := r.FormFile("audio")
		if err == nil {
			defer audioFile.Close()
			data, _ := io.ReadAll(audioFile)
			ext := filepath.Ext(audioHeader.Filename)
			if ext == "" {
				ext = ".m4a"
			}
			savedPath, err := service.SaveFile(filepath.Join(h.UploadDir, "audio"), data, ext)
			if err == nil {
				audioURL = &savedPath
				slog.Info("Audio saved", "path", savedPath, "size", len(data))

				// Transcribe if no text provided
				if text == nil || *text == "" {
					if h.ASR != nil {
						transcribed, err := h.ASR.Transcribe(savedPath)
						if err != nil {
							slog.Error("ASR failed", "err", err)
						} else if transcribed != "" {
							text = &transcribed
							slog.Info("ASR transcribed", "text", transcribed)
						}
					}
				}
			} else {
				slog.Error("Save audio failed", "err", err)
			}
		}

		// Handle image files
		if r.MultipartForm != nil && r.MultipartForm.File != nil {
			for _, fileHeaders := range r.MultipartForm.File {
				for _, fh := range fileHeaders {
					if strings.HasPrefix(fh.Header.Get("Content-Disposition"), "form-data; name=\"audio\"") {
						continue
					}
					if !strings.Contains(fh.Header.Get("Content-Disposition"), "name=\"images\"") {
						continue
					}
					f, err := fh.Open()
					if err != nil {
						continue
					}
					data, _ := io.ReadAll(f)
					f.Close()
					ext := filepath.Ext(fh.Filename)
					if ext == "" {
						ext = ".jpg"
					}
					savedPath, err := service.SaveFile(filepath.Join(h.UploadDir, "images"), data, ext)
					if err == nil {
						imageURLs = append(imageURLs, savedPath)
						slog.Info("Image saved", "path", savedPath, "size", len(data))
					}
				}
			}
		}

		// If still no text after ASR, and we have images, set a description
		if (text == nil || *text == "") && len(imageURLs) > 0 {
			desc := fmt.Sprintf("请分析这%d张图片", len(imageURLs))
			text = &desc
		}
	} else {
		var body struct {
			Text         *string `json:"text"`
			ParentTaskID *string `json:"parent_task_id"`
			SessionID    *string `json:"session_id"`
		}
		json.NewDecoder(r.Body).Decode(&body)
		text = body.Text
		parentTaskID = body.ParentTaskID
		sessionID = body.SessionID
	}

	if text == nil || *text == "" {
		http.Error(w, `{"error":"No text provided and transcription failed"}`, http.StatusBadRequest)
		return
	}

	// Insert task
	var taskID string
	var createdAt time.Time

	if len(imageURLs) > 0 {
		err := db.Pool.QueryRow(context.Background(),
			`INSERT INTO tasks (user_id, session_id, input_text, input_audio_url, input_image_urls, parent_task_id, status)
			 VALUES ($1, $2, $3, $4, $5, $6, 'created') RETURNING id, created_at`,
			userID, sessionID, text, audioURL, imageURLs, parentTaskID).Scan(&taskID, &createdAt)
		if err != nil {
			http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), http.StatusInternalServerError)
			return
		}
	} else {
		err := db.Pool.QueryRow(context.Background(),
			`INSERT INTO tasks (user_id, session_id, input_text, input_audio_url, parent_task_id, status)
			 VALUES ($1, $2, $3, $4, $5, 'created') RETURNING id, created_at`,
			userID, sessionID, text, audioURL, parentTaskID).Scan(&taskID, &createdAt)
		if err != nil {
			http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), http.StatusInternalServerError)
			return
		}
	}

	if sessionID != nil {
		db.Pool.Exec(context.Background(),
			`UPDATE sessions SET updated_at = NOW() WHERE id = $1`, *sessionID)
	}

	inputText := ""
	if text != nil {
		inputText = *text
	}

	h.Hub.Send(userID, model.PushEvent{
		Type: "task_created",
		Task: &model.TaskBrief{
			ID:        taskID,
			InputText: inputText,
			Status:    string(model.TaskStatusCreated),
			CreatedAt: createdAt.Format(time.RFC3339),
		},
	})

	if h.OpenClawClient != nil {
		gwURL := h.OpenClawClient.GetGatewayURL(userID)
		if gwURL != "" {
			go h.routeViaOpenClaw(userID, taskID, inputText)
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{"taskId": taskID, "status": "created", "route": "openclaw"})
			return
		}
	}

	if h.Queue != nil {
		h.Queue.EnqueueUnderstand(taskID)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"taskId": taskID, "status": "created"})
}

func (h *CommandHandler) routeViaOpenClaw(userID, taskID, text string) {
	if err := h.OpenClawClient.EnsureConnected(userID); err != nil {
		slog.Warn("OpenClaw connection failed, falling back to built-in AI", "userID", userID, "err", err)
		if h.Queue != nil {
			h.Queue.EnqueueUnderstand(taskID)
		}
		return
	}

	h.Hub.Send(userID, model.PushEvent{
		Type:    "task_progress",
		TaskID:  taskID,
		Message: "正在通过 OpenClaw 处理…",
	})

	if err := h.OpenClawClient.SendMessage(userID, text); err != nil {
		slog.Warn("OpenClaw send failed, falling back", "err", err)
		if h.Queue != nil {
			h.Queue.EnqueueUnderstand(taskID)
		}
	}
}

func (h *CommandHandler) FollowUp(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	parentTaskID := r.PathValue("id")

	var body struct {
		Text string `json:"text"`
	}
	json.NewDecoder(r.Body).Decode(&body)
	if body.Text == "" {
		http.Error(w, `{"error":"Text is required"}`, http.StatusBadRequest)
		return
	}

	var taskID string
	var createdAt time.Time
	err := db.Pool.QueryRow(context.Background(),
		`INSERT INTO tasks (user_id, input_text, parent_task_id, status)
		 VALUES ($1, $2, $3, 'created') RETURNING id, created_at`,
		userID, body.Text, parentTaskID).Scan(&taskID, &createdAt)

	if err != nil {
		http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), http.StatusInternalServerError)
		return
	}

	h.Hub.Send(userID, model.PushEvent{
		Type: "task_created",
		Task: &model.TaskBrief{
			ID:        taskID,
			InputText: body.Text,
			Status:    "created",
			CreatedAt: createdAt.Format(time.RFC3339),
		},
	})

	if h.Queue != nil {
		h.Queue.EnqueueUnderstand(taskID)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"taskId": taskID, "status": "created"})
}
