# 语音交互闭环 (Voice Interaction Loop)

本目录包含「按住说话 → 执行反馈」交互通道的类型定义与状态机。

语音闭环是管理者与 Agent Teams 之间的输入通道之一（产品还支持文字和图片输入）。

关联文档：
- 产品需求：[docs/prd.md](../../docs/prd.md)
- 语音闭环设计：[docs/voice-interaction-loop.md](../../docs/voice-interaction-loop.md)
- 设计规范：[docs/design-guidelines.md](../../docs/design-guidelines.md)
- 功能清单：[docs/feature-list.md](../../docs/feature-list.md)

## 文件说明

- **types.ts**：状态、用户/系统事件、意图理解结果、各层反馈的类型。包含多任务类型（`GlobalInputState`、`TaskLoopState`、`MultiTaskContext`、`TaskAttribution`）和兼容旧版单任务类型（`VoiceLoopState`、`VoiceLoopContext`）。
- **state-machine.ts**：状态流转函数。多任务模式使用 `getNextInputState`（全局输入）和 `getNextTaskState`（单任务闭环）；兼容旧版 `getNextState`。
- **index.ts**：统一导出。

## 多任务模型

多任务下状态机分为两层：

1. **全局输入状态机**（`GlobalInputState`）：管理录音/转写，始终只有一个实例。用户随时可以发起新录音。
2. **任务闭环状态机**（`TaskLoopState`）：每个任务独立一个实例（Understanding → Executing → ResultReady），互不阻塞。

详见 [docs/voice-interaction-loop.md](../../docs/voice-interaction-loop.md) 第 8 节。
