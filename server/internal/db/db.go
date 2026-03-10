package db

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

var Pool *pgxpool.Pool

func Connect(databaseURL string) error {
	var err error
	Pool, err = pgxpool.New(context.Background(), databaseURL)
	if err != nil {
		return fmt.Errorf("unable to connect to database: %w", err)
	}
	return Pool.Ping(context.Background())
}

func Close() {
	if Pool != nil {
		Pool.Close()
	}
}

const SchemaSQL = `
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone VARCHAR(20) UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_profiles (
  user_id UUID PRIMARY KEY REFERENCES users(id),
  profile JSONB NOT NULL DEFAULT '{}',
  initialized BOOLEAN DEFAULT FALSE,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  rule_text TEXT NOT NULL,
  rule_parsed JSONB,
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  title TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  session_id UUID REFERENCES sessions(id),
  parent_task_id UUID,
  input_text TEXT,
  input_audio_url TEXT,
  input_image_urls TEXT[],
  understanding TEXT,
  execution_plan JSONB,
  risk_level VARCHAR(10),
  intent_type VARCHAR(20),
  status VARCHAR(20) NOT NULL DEFAULT 'created',
  result JSONB,
  error TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sub_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id),
  step_index INT NOT NULL,
  description TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'pending',
  result JSONB,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS execution_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id),
  sub_task_id UUID REFERENCES sub_tasks(id),
  event_type VARCHAR(50) NOT NULL,
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS memories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  task_id UUID REFERENCES tasks(id),
  content TEXT NOT NULL,
  memory_type VARCHAR(20),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS task_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  source_task_id UUID REFERENCES tasks(id),
  title TEXT NOT NULL,
  description TEXT,
  assignee TEXT,
  priority VARCHAR(10) DEFAULT 'medium',
  status VARCHAR(20) DEFAULT 'open',
  deadline TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS scheduled_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  source_text TEXT,
  job_type VARCHAR(20) NOT NULL,
  schedule VARCHAR(100),
  context JSONB,
  active BOOLEAN DEFAULT TRUE,
  next_run_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_tasks_user_status ON tasks(user_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_user_created ON tasks(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sub_tasks_task ON sub_tasks(task_id);
CREATE INDEX IF NOT EXISTS idx_logs_task ON execution_logs(task_id, created_at);
CREATE INDEX IF NOT EXISTS idx_memories_user ON memories(user_id);
CREATE INDEX IF NOT EXISTS idx_task_items_user ON task_items(user_id, status);
`

func Migrate() error {
	_, err := Pool.Exec(context.Background(), SchemaSQL)
	if err != nil {
		return err
	}

	migrations := []string{
		`ALTER TABLE tasks ADD COLUMN IF NOT EXISTS session_id UUID REFERENCES sessions(id)`,
		`CREATE INDEX IF NOT EXISTS idx_tasks_session ON tasks(session_id, created_at)`,
		`CREATE TABLE IF NOT EXISTS user_accounts (
		  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		  user_id UUID NOT NULL REFERENCES users(id),
		  platform VARCHAR(30) NOT NULL,
		  display_name TEXT,
		  credentials_enc TEXT NOT NULL,
		  created_at TIMESTAMPTZ DEFAULT NOW(),
		  updated_at TIMESTAMPTZ DEFAULT NOW(),
		  UNIQUE(user_id, platform, display_name)
		)`,
		`CREATE TABLE IF NOT EXISTS push_tokens (
		  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		  user_id UUID NOT NULL REFERENCES users(id),
		  device_token TEXT NOT NULL,
		  platform VARCHAR(10) DEFAULT 'ios',
		  created_at TIMESTAMPTZ DEFAULT NOW(),
		  updated_at TIMESTAMPTZ DEFAULT NOW(),
		  UNIQUE(user_id, device_token)
		)`,
	}
	for _, m := range migrations {
		if _, err := Pool.Exec(context.Background(), m); err != nil {
			return fmt.Errorf("migration failed: %w", err)
		}
	}
	return nil
}
