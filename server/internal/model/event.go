package model

type PushEvent struct {
	Type      string      `json:"type"`
	TaskID    string      `json:"taskId,omitempty"`
	Task      *TaskBrief  `json:"task,omitempty"`
	Message   string      `json:"message,omitempty"`
	Result    *ResultCard `json:"result,omitempty"`
	Reason    string      `json:"reason,omitempty"`
	Step      string      `json:"step,omitempty"`
	SessionID string      `json:"sessionId,omitempty"`
	Title     string      `json:"title,omitempty"`
}

type TaskBrief struct {
	ID            string           `json:"id"`
	InputText     string           `json:"inputText"`
	Understanding string           `json:"understanding"`
	Status        string           `json:"status"`
	CreatedAt     string           `json:"createdAt"`
	Steps         []ExecutionStep  `json:"steps,omitempty"`
}

type ResultCard struct {
	Title string            `json:"title"`
	Body  string            `json:"body,omitempty"`
	Items []ResultCardItem  `json:"items,omitempty"`
}

type ResultCardItem struct {
	Label string `json:"label"`
	Value string `json:"value,omitempty"`
}

type UnderstandingResult struct {
	Understanding string        `json:"understanding"`
	ExecutionPlan ExecutionPlan  `json:"execution_plan"`
	RiskLevel     string        `json:"risk_level"`
	IntentType    string        `json:"intent_type"`
	RelatedTaskID *string       `json:"related_task_id"`
}

type ExecutionPlan struct {
	Steps                []ExecutionStep `json:"steps"`
	RequiresConfirmation bool           `json:"requires_confirmation"`
	ConfirmationMessage  string         `json:"confirmation_message,omitempty"`
}

type ExecutionStep struct {
	Description string   `json:"description"`
	ToolsNeeded []string `json:"tools_needed,omitempty"`
	CanParallel bool     `json:"can_parallel,omitempty"`
}
