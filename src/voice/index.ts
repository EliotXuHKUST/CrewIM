/**
 * 语音交互闭环 — 对外导出
 * 设计文档：docs/voice-interaction-loop.md
 * 功能清单：docs/feature-list.md
 */

export type {
  // 兼容旧版单任务
  VoiceLoopState,
  VoiceLoopUserEvent,
  VoiceLoopSystemEvent,
  VoiceLoopEvent,
  VoiceLoopContext,
  // 多任务
  GlobalInputState,
  GlobalInputContext,
  TaskLoopState,
  TaskLoopContext,
  MultiTaskContext,
  TaskAttribution,
  // 共用类型
  IntentResult,
  InstantFeedback,
  ProgressFeedback,
  ResultFeedback,
  ResultCard,
  ResultAction,
  ConfirmationPayload,
  FailureFeedback,
} from './types';

export {
  // 兼容旧版单任务
  getNextState,
  canStartRecording,
  canCancel,
  // 多任务
  getNextInputState,
  getNextTaskState,
  canStartRecordingMultiTask,
  canCancelInput,
  isTaskActive,
  taskNeedsAttention,
} from './state-machine';
