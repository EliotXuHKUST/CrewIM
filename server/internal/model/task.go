package model

import (
	"encoding/json"
	"time"
)

type TaskStatus string

const (
	TaskStatusCreated        TaskStatus = "created"
	TaskStatusUnderstanding  TaskStatus = "understanding"
	TaskStatusWaitingConfirm TaskStatus = "waiting_confirm"
	TaskStatusExecuting      TaskStatus = "executing"
	TaskStatusPaused         TaskStatus = "paused"
	TaskStatusCompleted      TaskStatus = "completed"
	TaskStatusFailed         TaskStatus = "failed"
	TaskStatusCancelled      TaskStatus = "cancelled"
)

type Task struct {
	ID             string          `json:"id" db:"id"`
	UserID         string          `json:"userId" db:"user_id"`
	ParentTaskID   *string         `json:"parentTaskId,omitempty" db:"parent_task_id"`
	InputText      *string         `json:"inputText,omitempty" db:"input_text"`
	InputAudioURL  *string         `json:"inputAudioUrl,omitempty" db:"input_audio_url"`
	InputImageURLs []string        `json:"inputImageUrls,omitempty" db:"input_image_urls"`
	Understanding  *string         `json:"understanding,omitempty" db:"understanding"`
	ExecutionPlan  json.RawMessage `json:"executionPlan,omitempty" db:"execution_plan"`
	RiskLevel      *string         `json:"riskLevel,omitempty" db:"risk_level"`
	IntentType     *string         `json:"intentType,omitempty" db:"intent_type"`
	Status         TaskStatus      `json:"status" db:"status"`
	Result         json.RawMessage `json:"result,omitempty" db:"result"`
	Error          *string         `json:"error,omitempty" db:"error"`
	CreatedAt      time.Time       `json:"createdAt" db:"created_at"`
	UpdatedAt      time.Time       `json:"updatedAt" db:"updated_at"`
}

type SubTask struct {
	ID          string          `json:"id" db:"id"`
	TaskID      string          `json:"taskId" db:"task_id"`
	StepIndex   int             `json:"stepIndex" db:"step_index"`
	Description string          `json:"description" db:"description"`
	Status      string          `json:"status" db:"status"`
	Result      json.RawMessage `json:"result,omitempty" db:"result"`
	StartedAt   *time.Time      `json:"startedAt,omitempty" db:"started_at"`
	CompletedAt *time.Time      `json:"completedAt,omitempty" db:"completed_at"`
}

type ExecutionLog struct {
	ID        string          `json:"id" db:"id"`
	TaskID    string          `json:"taskId" db:"task_id"`
	SubTaskID *string         `json:"subTaskId,omitempty" db:"sub_task_id"`
	EventType string          `json:"eventType" db:"event_type"`
	Payload   json.RawMessage `json:"payload,omitempty" db:"payload"`
	CreatedAt time.Time       `json:"createdAt" db:"created_at"`
}
