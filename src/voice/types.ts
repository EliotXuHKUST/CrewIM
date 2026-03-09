/**
 * 语音交互闭环 — 类型定义
 * 与 docs/voice-interaction-loop.md 一一对应，供前端/后端实现使用。
 *
 * 注意：语音闭环是管理者与 Agent Teams 之间的一种交互通道。
 * 产品核心循环是 "意图 → 大模型理解 → Agent Teams 执行 → 结果"，
 * 语音闭环对应的是管理者"输入指令"这一步的实现。
 * 参考 docs/prd.md 第五节核心架构。
 */

// ============ 状态 ============

export type VoiceLoopState =
  | 'Idle'
  | 'Recording'
  | 'Transcribing'
  | 'Understanding'
  | 'Executing'
  | 'NeedsConfirmation'
  | 'ResultReady'
  | 'Failed';

// ============ 用户事件 ============

export type VoiceLoopUserEvent =
  | { type: 'press_start' }
  | { type: 'press_end' }
  | { type: 'cancel' }
  | { type: 'confirm' }
  | { type: 'reject' }
  | { type: 'dismiss' }
  | { type: 'follow_up' };

// ============ 系统事件 ============

export type VoiceLoopSystemEvent =
  | { type: 'transcribe_done'; payload: { text: string } }
  | { type: 'transcribe_fail'; payload: { reason: string } }
  | { type: 'intent_ready'; payload: IntentResult }
  | { type: 'intent_fail'; payload: { reason: string; missingParams?: string[] } }
  | { type: 'execution_progress'; payload: ProgressFeedback }
  | { type: 'execution_done'; payload: ResultFeedback }
  | { type: 'execution_fail'; payload: FailureFeedback }
  | { type: 'confirmation_required'; payload: ConfirmationPayload };

export type VoiceLoopEvent = VoiceLoopUserEvent | VoiceLoopSystemEvent;

// ============ 意图理解结果 ============

export interface IntentResult {
  /** 大模型对指令的理解描述（展示给用户确认） */
  understanding: string;
  /** 执行计划（由大模型生成，交给 Agent Teams 执行） */
  executionPlan: {
    steps: Array<{ description: string; toolsNeeded?: string[]; canParallel?: boolean }>;
  };
  /** 风险级别：low 直接执行 / medium 建议确认 / high 必须确认 */
  riskLevel: 'low' | 'medium' | 'high';
  /** 意图类型（大模型自动判断） */
  intentType?: 'goal' | 'focus' | 'rule' | 'task';
  /** 是否需要用户确认后再执行 */
  requiresConfirmation: boolean;
  /** 确认时展示的文案 */
  confirmationMessage?: string;
  /** 关联的已有任务 ID（追问/补充时） */
  relatedTaskId?: string | null;
}

// ============ 反馈负载 ============

/** 立即反馈：已收到、正在处理 */
export interface InstantFeedback {
  level: 'instant';
  /** 播报与界面文案 */
  message: string;
}

/** 过程反馈：当前步骤 */
export interface ProgressFeedback {
  level: 'progress';
  /** 当前步骤描述 */
  message: string;
  /** 可选步骤标识，用于 UI 步骤条 */
  stepId?: string;
  /** 是否播报（可配置为静默） */
  tts?: boolean;
}

/** 结果反馈：执行完成 */
export interface ResultFeedback {
  level: 'result';
  /** 结果摘要（可播报） */
  summary: string;
  /** 结果卡片内容 */
  card: ResultCard;
  /** 可选后续操作 */
  actions?: ResultAction[];
}

/** 风险反馈：需用户确认 */
export interface ConfirmationPayload {
  level: 'confirmation';
  /** 即将执行的动作描述 */
  message: string;
  /** 影响范围（影响谁、影响什么） */
  impact?: string;
  /** 为什么需要用户拍板 */
  reason?: string;
  /** 确认后实际执行的请求体（由前端在用户确认后发送） */
  confirmPayload: unknown;
}

/** 失败反馈 */
export interface FailureFeedback {
  level: 'failure';
  /** 哪一步失败 */
  stepId?: string;
  /** 失败原因 */
  reason: string;
  /** 建议补救 */
  suggestion?: string;
  /** 是否可重试 */
  retryable: boolean;
}

// ============ 结果卡片与操作 ============

export interface ResultCard {
  title: string;
  body?: string;
  /** 列表、表格等结构化内容 */
  items?: Array<{ label: string; value?: string; [k: string]: unknown }>;
  /** 原始数据，供自定义展示 */
  raw?: unknown;
}

export interface ResultAction {
  id: string;
  label: string;
  /**  primary | secondary */
  variant?: string;
  payload?: unknown;
}

// ============ 全局输入状态（多任务下只有一个） ============

export type GlobalInputState = 'Idle' | 'Recording' | 'Transcribing';

export interface GlobalInputContext {
  state: GlobalInputState;
  /** 用户输入转写文本（转写完成后填入） */
  transcript: string | null;
  /** 用户附带的图片 URL 列表 */
  imageUrls: string[];
  /** 状态进入时间戳 */
  enteredAt: number;
}

// ============ 单任务闭环上下文 ============

export type TaskLoopState =
  | 'Understanding'
  | 'Executing'
  | 'NeedsConfirmation'
  | 'ResultReady'
  | 'Failed';

export interface TaskLoopContext {
  state: TaskLoopState;
  /** 任务 ID（与任务流对应） */
  taskId: string;
  /** 大模型理解结果 */
  intent: IntentResult | null;
  /** 最近一次反馈 */
  lastFeedback: InstantFeedback | ProgressFeedback | ResultFeedback | FailureFeedback | null;
  /** 待确认时的负载 */
  pendingConfirmation: ConfirmationPayload | null;
  /** 状态进入时间戳，用于超时等 */
  enteredAt: number;
}

// ============ 多任务管理器上下文 ============

export interface MultiTaskContext {
  /** 全局输入状态 */
  input: GlobalInputContext;
  /** 活跃任务列表（各自独立闭环） */
  activeTasks: TaskLoopContext[];
}

// ============ 任务归属判断结果 ============

export interface TaskAttribution {
  /** 是新任务还是旧任务追问 */
  type: 'new_task' | 'follow_up' | 'ambiguous';
  /** 如果是 follow_up，关联的已有任务 ID */
  relatedTaskId?: string;
  /** 如果是 ambiguous，大模型的候选任务列表 */
  candidates?: Array<{ taskId: string; description: string }>;
  /** 置信度 0—1 */
  confidence: number;
}

// ============ 兼容：单次闭环上下文（保留向后兼容） ============

export interface VoiceLoopContext {
  state: VoiceLoopState;
  /** 当前任务 ID（与任务流对应） */
  taskId: string | null;
  /** 用户输入转写文本 */
  transcript: string | null;
  /** 用户附带的图片 URL 列表 */
  imageUrls: string[];
  /** 大模型理解结果 */
  intent: IntentResult | null;
  /** 最近一次反馈 */
  lastFeedback: InstantFeedback | ProgressFeedback | ResultFeedback | FailureFeedback | null;
  /** 待确认时的负载 */
  pendingConfirmation: ConfirmationPayload | null;
  /** 状态进入时间戳，用于超时等 */
  enteredAt: number;
}
