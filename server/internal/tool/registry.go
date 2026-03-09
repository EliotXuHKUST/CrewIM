package tool

import (
	"fmt"

	"github.com/xiaozhong/command-center-server/internal/ai"
)

type Context struct {
	UserID    string
	TaskID    string
	SubTaskID string
}

type Result struct {
	Success bool   `json:"success"`
	Data    any    `json:"data,omitempty"`
	Error   string `json:"error,omitempty"`
}

type Definition struct {
	Name        string
	Description string
	Parameters  map[string]any
	Execute     func(params map[string]any, ctx Context) Result
}

type Registry struct {
	tools map[string]*Definition
}

func NewRegistry() *Registry {
	return &Registry{tools: make(map[string]*Definition)}
}

func (r *Registry) Register(d *Definition) {
	r.tools[d.Name] = d
}

func (r *Registry) Get(name string) (*Definition, bool) {
	d, ok := r.tools[name]
	return d, ok
}

func (r *Registry) ToAITools() []ai.Tool {
	result := make([]ai.Tool, 0, len(r.tools))
	for _, d := range r.tools {
		result = append(result, ai.Tool{
			Name:        d.Name,
			Description: d.Description,
			InputSchema: map[string]any{
				"type":       "object",
				"properties": d.Parameters,
			},
		})
	}
	return result
}

func (r *Registry) Execute(name string, params map[string]any, ctx Context) Result {
	d, ok := r.tools[name]
	if !ok {
		return Result{Success: false, Error: fmt.Sprintf("tool %s not found", name)}
	}
	return d.Execute(params, ctx)
}
