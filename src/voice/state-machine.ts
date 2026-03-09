/**
 * 语音交互闭环 — 状态流转规范
 * 与 docs/voice-interaction-loop.md 中的状态图、事件表一致。
 * 此处仅定义合法转移，具体副作用（请求、播报、UI）由调用方根据 state 与 event 执行。
 *
 * 多任务模型：
 * - 全局输入状态机（GlobalInputState）：管理录音/转写，始终只有一个实例。
 * - 任务闭环状态机（TaskLoopState）：每个任务独立一个实例，互不阻塞。
 * - 兼容旧版单任务 VoiceLoopState 状态机。
 */

import type {
  VoiceLoopState,
  VoiceLoopEvent,
  GlobalInputState,
  TaskLoopState,
} from './types';

// ============ 兼容旧版：单任务状态机 ============

export type TransitionResult = { nextState: VoiceLoopState } | { nextState: VoiceLoopState; payload: unknown };

/**
 * 根据当前状态与事件返回下一状态（及可选 payload）。
 * 非法转移返回 null，由调用方决定是否保持原状态或进入 Failed/Idle。
 */
export function getNextState(
  state: VoiceLoopState,
  event: VoiceLoopEvent
): TransitionResult | null {
  const e = event as { type: string; payload?: unknown };

  switch (state) {
    case 'Idle':
      if (e.type === 'press_start') return { nextState: 'Recording' };
      return null;

    case 'Recording':
      if (e.type === 'press_end') return { nextState: 'Transcribing' };
      if (e.type === 'cancel') return { nextState: 'Idle' };
      return null;

    case 'Transcribing':
      if (e.type === 'transcribe_done') return { nextState: 'Understanding', payload: e.payload };
      if (e.type === 'transcribe_fail') return { nextState: 'Failed', payload: e.payload };
      if (e.type === 'cancel') return { nextState: 'Idle' };
      return null;

    case 'Understanding':
      if (e.type === 'intent_ready') {
        const payload = e.payload as { requiresConfirmation?: boolean };
        return {
          nextState: payload?.requiresConfirmation ? 'NeedsConfirmation' : 'Executing',
          payload: e.payload,
        };
      }
      if (e.type === 'intent_fail') return { nextState: 'Idle', payload: e.payload };
      return null;

    case 'Executing':
      if (e.type === 'execution_progress') return { nextState: 'Executing', payload: e.payload };
      if (e.type === 'execution_done') return { nextState: 'ResultReady', payload: e.payload };
      if (e.type === 'execution_fail') return { nextState: 'Failed', payload: e.payload };
      if (e.type === 'confirmation_required') return { nextState: 'NeedsConfirmation', payload: e.payload };
      return null;

    case 'NeedsConfirmation':
      if (e.type === 'confirm') return { nextState: 'Executing' };
      if (e.type === 'reject') return { nextState: 'Idle' };
      return null;

    case 'ResultReady':
      if (e.type === 'dismiss') return { nextState: 'Idle' };
      if (e.type === 'follow_up') return { nextState: 'Recording' };
      return null;

    case 'Failed':
      if (e.type === 'dismiss') return { nextState: 'Idle' };
      if (e.type === 'follow_up') return { nextState: 'Recording' };
      return null;

    default:
      return null;
  }
}

// ============ 多任务：全局输入状态机 ============

export type GlobalInputEvent =
  | { type: 'press_start' }
  | { type: 'press_end' }
  | { type: 'cancel' }
  | { type: 'transcribe_done'; payload: { text: string } }
  | { type: 'transcribe_fail'; payload: { reason: string } };

/**
 * 全局输入状态流转。
 * 多任务下录音/转写始终只有一个，完成后回到 Idle，新任务由 TaskLoop 接管。
 */
export function getNextInputState(
  state: GlobalInputState,
  event: GlobalInputEvent
): { nextState: GlobalInputState; payload?: unknown } | null {
  switch (state) {
    case 'Idle':
      if (event.type === 'press_start') return { nextState: 'Recording' };
      return null;

    case 'Recording':
      if (event.type === 'press_end') return { nextState: 'Transcribing' };
      if (event.type === 'cancel') return { nextState: 'Idle' };
      return null;

    case 'Transcribing':
      if (event.type === 'transcribe_done') return { nextState: 'Idle', payload: event.payload };
      if (event.type === 'transcribe_fail') return { nextState: 'Idle', payload: event.payload };
      if (event.type === 'cancel') return { nextState: 'Idle' };
      return null;

    default:
      return null;
  }
}

// ============ 多任务：单任务闭环状态机 ============

export type TaskLoopEvent =
  | { type: 'intent_ready'; payload: { requiresConfirmation?: boolean; [k: string]: unknown } }
  | { type: 'intent_fail'; payload: { reason: string } }
  | { type: 'execution_progress'; payload: unknown }
  | { type: 'execution_done'; payload: unknown }
  | { type: 'execution_fail'; payload: unknown }
  | { type: 'confirmation_required'; payload: unknown }
  | { type: 'confirm' }
  | { type: 'reject' }
  | { type: 'cancel' };

/**
 * 单任务闭环状态流转。
 * 每个任务独立运行，互不阻塞。
 */
export function getNextTaskState(
  state: TaskLoopState,
  event: TaskLoopEvent
): { nextState: TaskLoopState; payload?: unknown } | null {
  switch (state) {
    case 'Understanding':
      if (event.type === 'intent_ready') {
        const p = event.payload as { requiresConfirmation?: boolean };
        return {
          nextState: p?.requiresConfirmation ? 'NeedsConfirmation' : 'Executing',
          payload: event.payload,
        };
      }
      if (event.type === 'intent_fail') return { nextState: 'Failed', payload: event.payload };
      return null;

    case 'Executing':
      if (event.type === 'execution_progress') return { nextState: 'Executing', payload: event.payload };
      if (event.type === 'execution_done') return { nextState: 'ResultReady', payload: event.payload };
      if (event.type === 'execution_fail') return { nextState: 'Failed', payload: event.payload };
      if (event.type === 'confirmation_required') return { nextState: 'NeedsConfirmation', payload: event.payload };
      if (event.type === 'cancel') return { nextState: 'Failed', payload: { reason: 'cancelled' } };
      return null;

    case 'NeedsConfirmation':
      if (event.type === 'confirm') return { nextState: 'Executing' };
      if (event.type === 'reject') return { nextState: 'Failed', payload: { reason: 'rejected' } };
      return null;

    case 'ResultReady':
      return null;

    case 'Failed':
      return null;

    default:
      return null;
  }
}

// ============ 辅助函数 ============

/**
 * 全局输入是否允许开始新录音。
 * 多任务下只看全局输入状态，不看任务状态。
 */
export function canStartRecordingMultiTask(inputState: GlobalInputState): boolean {
  return inputState === 'Idle';
}

/**
 * 兼容旧版：哪些状态应展示「按住说话」主按钮（可录音）。
 */
export function canStartRecording(state: VoiceLoopState): boolean {
  return state === 'Idle' || state === 'ResultReady' || state === 'Failed';
}

/**
 * 全局输入是否可取消。
 */
export function canCancelInput(inputState: GlobalInputState): boolean {
  return inputState === 'Recording' || inputState === 'Transcribing';
}

/**
 * 兼容旧版：哪些状态应展示全局取消/返回。
 */
export function canCancel(state: VoiceLoopState): boolean {
  return ['Recording', 'Transcribing'].includes(state);
}

/**
 * 任务是否处于活跃状态（需要在任务流中展示为活跃）。
 */
export function isTaskActive(state: TaskLoopState): boolean {
  return state === 'Understanding' || state === 'Executing' || state === 'NeedsConfirmation';
}

/**
 * 任务是否需要用户介入。
 */
export function taskNeedsAttention(state: TaskLoopState): boolean {
  return state === 'NeedsConfirmation' || state === 'Failed';
}
