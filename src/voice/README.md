# Voice Interaction Loop — `src/voice/`

「按住说话 → 大模型理解 → Agent Teams 执行 → 结果反馈」交互通道的类型定义与状态机。

语音闭环是管理者与 Agent Teams 之间的核心输入通道之一（产品还支持文字和图片输入），完整产品架构见 [docs/prd.md](../../docs/prd.md)。

## 架构概览

```
┌──────────────────────────────────────────────────────────────┐
│                     全局输入状态机                             │
│         Idle ──► Recording ──► Transcribing ──► Idle         │
│                                    │                         │
│                          转写完成，创建任务                     │
└────────────────────────────────────┼─────────────────────────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              ▼                      ▼                      ▼
      ┌─────────────┐       ┌─────────────┐       ┌─────────────┐
      │   任务 A      │       │   任务 B      │       │   任务 C      │
      │ Understanding│       │  Executing   │       │ ResultReady  │
      │  → Executing │       │  → Result    │       │              │
      │  → Result    │       │              │       │              │
      └─────────────┘       └─────────────┘       └─────────────┘
              各任务独立闭环，互不阻塞
```

## 文件说明

| 文件 | 职责 |
|------|------|
| `types.ts` | 所有状态、事件、反馈负载的 TypeScript 类型定义 |
| `state-machine.ts` | 纯函数状态流转逻辑（无副作用） |
| `index.ts` | 统一对外导出 |

## 状态机

### 多任务模型（推荐）

多任务下状态机分两层，**全局输入**只有一个实例，**任务闭环**按任务独立运行：

#### 全局输入状态机 — `GlobalInputState`

管理录音和转写，转写完成后回到 Idle 并创建新任务。

```
Idle ──press_start──► Recording ──press_end──► Transcribing ──transcribe_done──► Idle
  ▲                      │                         │
  └──────cancel──────────┘                         │
  └──────────────────cancel / transcribe_fail──────┘
```

**核心函数：**

```typescript
import { getNextInputState, canStartRecordingMultiTask, canCancelInput } from 'src/voice';

const result = getNextInputState('Idle', { type: 'press_start' });
// → { nextState: 'Recording' }
```

#### 任务闭环状态机 — `TaskLoopState`

每个任务从 Understanding 开始，独立流转至 ResultReady 或 Failed。

```
Understanding ──intent_ready──► Executing ──execution_done──► ResultReady
      │                            │    │
      │ intent_fail                │    └──confirmation_required──► NeedsConfirmation
      ▼                            │                                   │    │
    Failed ◄──execution_fail───────┘                   confirm ────────┘    │
      ▲                                                reject ─► Failed     │
      └─────────────────────────────────────────────────────────────────────┘
```

**核心函数：**

```typescript
import { getNextTaskState, isTaskActive, taskNeedsAttention } from 'src/voice';

const result = getNextTaskState('Executing', { type: 'execution_done', payload: { ... } });
// → { nextState: 'ResultReady', payload: { ... } }

isTaskActive('Executing');          // true — 任务仍在运转
taskNeedsAttention('NeedsConfirmation'); // true — 需要用户介入
```

### 兼容单任务模型

保留向后兼容的 `VoiceLoopState` 全链路状态机（Idle → Recording → ... → ResultReady），适用于单次指令场景。

```typescript
import { getNextState, canStartRecording, canCancel } from 'src/voice';

const result = getNextState('Idle', { type: 'press_start' });
// → { nextState: 'Recording' }
```

## 导出类型一览

### 状态与上下文

| 类型 | 说明 |
|------|------|
| `GlobalInputState` | `'Idle' \| 'Recording' \| 'Transcribing'` |
| `GlobalInputContext` | 全局输入上下文（状态 + 转写文本 + 图片） |
| `TaskLoopState` | `'Understanding' \| 'Executing' \| 'NeedsConfirmation' \| 'ResultReady' \| 'Failed'` |
| `TaskLoopContext` | 单任务闭环上下文（状态 + 意图 + 反馈 + 确认） |
| `MultiTaskContext` | 聚合上下文：全局输入 + 活跃任务列表 |
| `VoiceLoopState` | 兼容旧版全链路状态 |
| `VoiceLoopContext` | 兼容旧版上下文 |

### 事件

| 类型 | 说明 |
|------|------|
| `VoiceLoopUserEvent` | 用户侧事件：`press_start` / `press_end` / `cancel` / `confirm` / `reject` / `dismiss` / `follow_up` |
| `VoiceLoopSystemEvent` | 系统侧事件：`transcribe_done` / `intent_ready` / `execution_done` 等 |

### 数据负载

| 类型 | 说明 |
|------|------|
| `IntentResult` | 大模型意图理解结果（含执行计划、风险级别、是否需确认） |
| `TaskAttribution` | 任务归属判断：新任务 / 追问 / 不确定 |
| `InstantFeedback` | 立即反馈：「已收到，正在处理」 |
| `ProgressFeedback` | 过程反馈：当前步骤描述 |
| `ResultFeedback` | 结果反馈：摘要 + 结果卡片 + 可选操作 |
| `ConfirmationPayload` | 风险反馈：需用户确认的操作详情 |
| `FailureFeedback` | 失败反馈：原因 + 建议补救 + 是否可重试 |
| `ResultCard` | 结果卡片（标题 / 正文 / 列表） |
| `ResultAction` | 结果卡片内的可操作按钮 |

## 设计约定

1. **纯函数、无副作用** — 状态机只返回下一状态，不触发网络请求、TTS 播报或 UI 变更；副作用由调用方根据返回值执行。
2. **非法转移返回 `null`** — 调用方自行决定保持原状态还是进入 Failed/Idle。
3. **反馈分四层** — Instant → Progress → Result → Confirmation，详见 [voice-interaction-loop.md §5](../../docs/voice-interaction-loop.md)。
4. **任务归属由大模型判断** — 转写完成后，Understanding 阶段通过 `IntentResult.relatedTaskId` 决定是新任务还是追问。

## 关联文档

- [产品需求](../../docs/prd.md)
- [语音闭环设计](../../docs/voice-interaction-loop.md)
- [设计规范](../../docs/design-guidelines.md)
- [技术架构](../../docs/technical-architecture.md)
- [功能清单](../../docs/feature-list.md)
