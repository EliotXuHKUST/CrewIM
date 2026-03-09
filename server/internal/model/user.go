package model

import (
	"encoding/json"
	"time"
)

type User struct {
	ID        string    `json:"id" db:"id"`
	Phone     string    `json:"phone" db:"phone"`
	CreatedAt time.Time `json:"createdAt" db:"created_at"`
}

type UserProfile struct {
	UserID      string          `json:"userId" db:"user_id"`
	Profile     json.RawMessage `json:"profile" db:"profile"`
	Initialized bool            `json:"initialized" db:"initialized"`
	UpdatedAt   time.Time       `json:"updatedAt" db:"updated_at"`
}

type UserRule struct {
	ID         string          `json:"id" db:"id"`
	UserID     string          `json:"userId" db:"user_id"`
	RuleText   string          `json:"ruleText" db:"rule_text"`
	RuleParsed json.RawMessage `json:"ruleParsed,omitempty" db:"rule_parsed"`
	Active     bool            `json:"active" db:"active"`
	CreatedAt  time.Time       `json:"createdAt" db:"created_at"`
}
