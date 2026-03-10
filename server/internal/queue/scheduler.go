package queue

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/xiaozhong/command-center-server/internal/ai"
	"github.com/xiaozhong/command-center-server/internal/db"
	"github.com/xiaozhong/command-center-server/internal/model"
	"github.com/xiaozhong/command-center-server/internal/ws"
)

type Scheduler struct {
	hub    *ws.Hub
	claude *ai.ClaudeClient
	stop   chan struct{}
}

func NewScheduler(hub *ws.Hub, claude *ai.ClaudeClient) *Scheduler {
	return &Scheduler{hub: hub, claude: claude, stop: make(chan struct{})}
}

func (s *Scheduler) Start() {
	go s.loop()
	slog.Info("Scheduler started")
}

func (s *Scheduler) Stop() {
	close(s.stop)
}

func (s *Scheduler) loop() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-s.stop:
			return
		case <-ticker.C:
			s.processDueJobs()
		}
	}
}

func (s *Scheduler) processDueJobs() {
	ctx := context.Background()
	now := time.Now()

	rows, err := db.Pool.Query(ctx,
		`SELECT id, user_id, source_text, job_type, schedule, context, next_run_at
		 FROM scheduled_jobs
		 WHERE active = true AND next_run_at <= $1
		 ORDER BY next_run_at ASC LIMIT 20`, now)
	if err != nil {
		slog.Error("Scheduler query failed", "err", err)
		return
	}
	defer rows.Close()

	type job struct {
		ID         string
		UserID     string
		SourceText string
		JobType    string
		Schedule   string
		Context    json.RawMessage
		NextRunAt  time.Time
	}

	var jobs []job
	for rows.Next() {
		var j job
		if err := rows.Scan(&j.ID, &j.UserID, &j.SourceText, &j.JobType, &j.Schedule, &j.Context, &j.NextRunAt); err != nil {
			continue
		}
		jobs = append(jobs, j)
	}

	for _, j := range jobs {
		s.executeJob(j.ID, j.UserID, j.SourceText, j.JobType, j.Schedule, j.Context)
	}
}

func (s *Scheduler) executeJob(jobID, userID, sourceText, jobType, schedule string, ctxJSON json.RawMessage) {
	ctx := context.Background()

	var jobCtx map[string]string
	json.Unmarshal(ctxJSON, &jobCtx)

	message := jobCtx["message"]
	if message == "" {
		message = sourceText
	}

	result, err := s.claude.CallSimple(
		"你是管理者的 AI 参谋。现在到了一个定时提醒的时间点。请根据提醒内容，生成一条简洁有用的提醒消息。直接输出内容。",
		fmt.Sprintf("提醒内容：%s", message), 500)
	if err != nil {
		slog.Error("Scheduler Claude call failed", "jobId", jobID, "err", err)
		result = message
	}

	var taskID string
	db.Pool.QueryRow(ctx,
		`INSERT INTO tasks (user_id, input_text, understanding, status, result)
		 VALUES ($1, $2, $3, 'completed', $4) RETURNING id`,
		userID,
		"[定时提醒] "+message,
		"定时提醒："+message,
		json.RawMessage(fmt.Sprintf(`{"title":"定时提醒","body":"%s"}`, escapeJSON(result))),
	).Scan(&taskID)

	s.hub.Send(userID, model.PushEvent{
		Type:   "task_completed",
		TaskID: taskID,
		Result: &model.ResultCard{Title: "定时提醒", Body: result},
		Task:   &model.TaskBrief{ID: taskID, Understanding: message, Status: "completed"},
	})

	switch jobType {
	case "once":
		db.Pool.Exec(ctx, `UPDATE scheduled_jobs SET active = false WHERE id = $1`, jobID)
	case "cron":
		nextRun := parseCronNext(schedule)
		if nextRun.IsZero() {
			nextRun = time.Now().Add(24 * time.Hour)
		}
		db.Pool.Exec(ctx,
			`UPDATE scheduled_jobs SET next_run_at = $1 WHERE id = $2`, nextRun, jobID)
	}

	slog.Info("Scheduled job executed", "jobId", jobID, "userId", userID, "type", jobType)
}

func parseCronNext(schedule string) time.Time {
	now := time.Now()
	schedule = strings.TrimSpace(schedule)

	if schedule == "" || schedule == "daily" {
		return time.Date(now.Year(), now.Month(), now.Day()+1, 9, 0, 0, 0, now.Location())
	}
	if schedule == "weekly" {
		return now.AddDate(0, 0, 7)
	}
	if schedule == "hourly" {
		return now.Add(time.Hour)
	}

	if strings.Contains(schedule, ":") {
		parts := strings.Split(schedule, ":")
		if len(parts) == 2 {
			var h, m int
			fmt.Sscanf(parts[0], "%d", &h)
			fmt.Sscanf(parts[1], "%d", &m)
			next := time.Date(now.Year(), now.Month(), now.Day(), h, m, 0, 0, now.Location())
			if next.Before(now) {
				next = next.AddDate(0, 0, 1)
			}
			return next
		}
	}

	return now.Add(24 * time.Hour)
}

func escapeJSON(s string) string {
	b, _ := json.Marshal(s)
	return string(b[1 : len(b)-1])
}
