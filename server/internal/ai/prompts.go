package ai

import (
	"fmt"
	"strings"
)

type UserContext struct {
	Profile     map[string]any
	Rules       []string
	ActiveTasks []struct{ Status, Understanding string }
	History     []struct{ Input, Understanding string }
	Memories    []string
}

func BuildUnderstandingPrompt(ctx UserContext) string {
	profileLines := "尚未设定"
	if len(ctx.Profile) > 0 {
		parts := make([]string, 0, len(ctx.Profile))
		for k, v := range ctx.Profile {
			parts = append(parts, fmt.Sprintf("%s: %v", k, v))
		}
		profileLines = strings.Join(parts, "\n")
	}

	rulesLines := "无"
	if len(ctx.Rules) > 0 {
		parts := make([]string, len(ctx.Rules))
		for i, r := range ctx.Rules {
			parts[i] = "- " + r
		}
		rulesLines = strings.Join(parts, "\n")
	}

	activeLines := "无"
	if len(ctx.ActiveTasks) > 0 {
		parts := make([]string, len(ctx.ActiveTasks))
		for i, t := range ctx.ActiveTasks {
			parts[i] = fmt.Sprintf("- [%s] %s", t.Status, t.Understanding)
		}
		activeLines = strings.Join(parts, "\n")
	}

	historyLines := "无"
	if len(ctx.History) > 0 {
		parts := make([]string, len(ctx.History))
		for i, h := range ctx.History {
			parts[i] = fmt.Sprintf("- %s → %s", h.Input, h.Understanding)
		}
		historyLines = strings.Join(parts, "\n")
	}

	memoryLines := "无"
	if len(ctx.Memories) > 0 {
		parts := make([]string, len(ctx.Memories))
		for i, m := range ctx.Memories {
			parts[i] = "- " + m
		}
		memoryLines = strings.Join(parts, "\n")
	}

	return fmt.Sprintf(`你是一位管理者的 AI 参谋长。你的唯一职责是：
准确理解管理者的指令，并转化为可执行的任务计划。

## 管理者信息
%s

## 管理者的规则
%s

## 当前正在进行的任务
%s

## 近期历史（供指代消解）
%s

## 相关记忆
%s

## 你的输出
严格返回以下 JSON（不要附加其他内容，不要用 markdown 代码块包裹）：
{
  "understanding": "用一句管理者能看懂的话描述你的理解",
  "execution_plan": {
    "steps": [
      {
        "description": "步骤描述",
        "tools_needed": ["需要的工具名"],
        "can_parallel": false
      }
    ],
    "requires_confirmation": false,
    "confirmation_message": ""
  },
  "risk_level": "low",
  "intent_type": "task",
  "related_task_id": null
}

## 风险判断
- 读取/整理/分析/生成/提醒 → "low"
- 涉及通知他人/修改数据/触发外部动作 → "medium"
- 大范围影响/不可逆/涉及敏感信息 → "high"

## intent_type 判断
- "goal": 持续性目标
- "focus": 持续性监控
- "rule": 持续性规则
- "task": 一次性管理动作`, profileLines, rulesLines, activeLines, historyLines, memoryLines)
}
