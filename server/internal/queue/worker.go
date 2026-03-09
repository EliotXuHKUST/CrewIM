package queue

import (
	"log/slog"
	"sync"

	"github.com/xiaozhong/command-center-server/internal/service"
)

type TaskQueue struct {
	understandCh chan string
	executeCh    chan string
	understand   *service.UnderstandingService
	orchestrator *service.Orchestrator
	wg           sync.WaitGroup
}

func NewTaskQueue(understand *service.UnderstandingService, orchestrator *service.Orchestrator) *TaskQueue {
	return &TaskQueue{
		understandCh: make(chan string, 100),
		executeCh:    make(chan string, 100),
		understand:   understand,
		orchestrator: orchestrator,
	}
}

func (q *TaskQueue) EnqueueUnderstand(taskID string) {
	q.understandCh <- taskID
}

func (q *TaskQueue) EnqueueExecute(taskID string) {
	q.executeCh <- taskID
}

func (q *TaskQueue) Start(concurrency int) {
	for i := 0; i < concurrency; i++ {
		q.wg.Add(1)
		go q.understandWorker(i)
	}
	for i := 0; i < concurrency; i++ {
		q.wg.Add(1)
		go q.executeWorker(i)
	}
	slog.Info("Queue workers started", "concurrency", concurrency)
}

func (q *TaskQueue) understandWorker(id int) {
	defer q.wg.Done()
	for taskID := range q.understandCh {
		slog.Info("Understanding task", "worker", id, "taskId", taskID)
		result, err := q.understand.Understand(taskID)
		if err != nil {
			slog.Error("Understanding failed", "taskId", taskID, "err", err)
			continue
		}
		if !result.ExecutionPlan.RequiresConfirmation {
			q.EnqueueExecute(taskID)
		}
	}
}

func (q *TaskQueue) executeWorker(id int) {
	defer q.wg.Done()
	for taskID := range q.executeCh {
		slog.Info("Executing task", "worker", id, "taskId", taskID)
		q.orchestrator.Execute(taskID)
	}
}

func (q *TaskQueue) Stop() {
	close(q.understandCh)
	close(q.executeCh)
	q.wg.Wait()
}
