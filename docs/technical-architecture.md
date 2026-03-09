# 知知 — 技术架构与开发计划（Flutter 版）

关联文档：[prd.md](prd.md)、[feature-list.md](feature-list.md)、[voice-interaction-loop.md](voice-interaction-loop.md)、[design-guidelines.md](design-guidelines.md)。

## 一、技术架构总览

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Flutter 客户端（iOS / Android / Web）              │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │                   Presentation Layer                          │    │
│  │  CommandScreen ─── TaskListScreen ─── TaskDetailScreen        │    │
│  │  OnboardingScreen ─── SettingsScreen (对话式)                 │    │
│  └──────────────────────────┬───────────────────────────────────┘    │
│                             │                                        │
│  ┌──────────────────────────┼───────────────────────────────────┐    │
│  │                   State Layer (Riverpod)                      │    │
│  │  commandNotifier ─ taskListNotifier ─ taskDetailNotifier      │    │
│  │  authNotifier ─ socketNotifier ─ audioRecorderNotifier        │    │
│  └──────────────────────────┬───────────────────────────────────┘    │
│                             │                                        │
│  ┌──────────────────────────┼───────────────────────────────────┐    │
│  │                   Domain Layer                                │    │
│  │  entities ─── repositories(abstract) ─── usecases             │    │
│  └──────────────────────────┬───────────────────────────────────┘    │
│                             │                                        │
│  ┌──────────────────────────┼───────────────────────────────────┐    │
│  │                   Data Layer                                  │    │
│  │  ApiClient(Dio) ─ SocketClient ─ AudioRecorder ─ ImagePicker  │    │
│  │  LocalStorage(Isar) ─ SecureStorage ─ FileUploader            │    │
│  └──────────────────────────┬───────────────────────────────────┘    │
│                             │  HTTPS + WebSocket                     │
└─────────────────────────────┼────────────────────────────────────────┘
                              │
┌─────────────────────────────┼────────────────────────────────────────┐
│                       API Gateway (Nginx)                             │
│              TLS 终止 / 认证 / 限流 / WebSocket 升级                   │
└─────────────────────────────┼────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│   指令服务      │  │   任务服务      │  │   推送服务      │
│  接收 / 预处理  │  │  状态 / 查询    │  │  WebSocket 管理 │
└───────┬────────┘  └───────┬────────┘  └───────┬────────┘
        │                   │                   │
        ▼                   ▼                   │
┌───────────────────────────────────────┐       │
│            理解层服务                   │       │
│                                       │       │
│  ┌───────────┐  ┌──────────────────┐  │       │
│  │ STT 转写   │  │ 大模型意图理解    │  │       │
│  │ (Whisper)  │  │ + 管理者上下文    │  │       │
│  └─────┬─────┘  └────────┬─────────┘  │       │
│        └────────┬────────┘            │       │
└─────────────────┼─────────────────────┘       │
                  │                             │
                  ▼                             │
┌───────────────────────────────────────┐       │
│        执行层 Agent Teams              │       │
│                                       │  状态变更 ──►
│  ┌──────────────────┐                 │       │
│  │  主 Agent (调度)   │                │       │
│  └─┬───┬───┬───┬────┘                │       │
│    ▼   ▼   ▼   ▼                     │       │
│  子 Agent 池（按需创建并行执行）        │       │
│                                       │       │
│  ┌──────────────────┐                 │       │
│  │  工具注册中心      │                 │       │
│  │ 内置工具 + 外部工具 │                │       │
│  └──────────────────┘                 │       │
└─────────────────┬─────────────────────┘       │
                  │                             │
                  ▼                             │
┌──────────────────────────────────────────────────────────────────────┐
│                            数据层                                     │
│                                                                      │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌─────────────────┐  │
│  │ PostgreSQL │  │  Redis     │  │ pgvector  │  │  OSS / S3       │  │
│  │ 用户/任务   │  │ 缓存/队列  │  │ 向量记忆   │  │ 音频/图片/文档  │  │
│  └───────────┘  └───────────┘  └───────────┘  └─────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

## 二、技术选型

### 2.1 Flutter 客户端

| 层级 | 组件 | 选型 | 理由 |
|------|------|------|------|
| 框架 | 跨平台 | Flutter 3.x (Dart) | iOS/Android/Web 一套代码，高性能渲染，生态完善 |
| 架构 | 状态管理 | Riverpod 2.x | 编译期安全、支持 async、依赖注入一体化、社区主流 |
| 架构 | 路由 | go_router | 声明式路由、深链接支持、Flutter 官方推荐 |
| 架构 | 代码生成 | freezed + json_serializable | 不可变数据类 + JSON 序列化，减少样板代码 |
| 网络 | HTTP | dio | 拦截器、取消、重试、multipart 上传 |
| 网络 | WebSocket | web_socket_channel + 自封装重连 | 轻量、Dart 原生、搭配 Riverpod StreamProvider |
| 音频 | 录音 | record | 跨平台录音，支持 AAC/WAV，按住说话场景 |
| 音频 | 播放 | just_audio | 结果播报（TTS 音频播放） |
| 图片 | 拍照/相册 | image_picker | 官方维护，iOS/Android 统一 API |
| 图片 | 压缩 | flutter_image_compress | 上传前压缩，减少流量和延迟 |
| 存储 | 本地数据库 | isar | 高性能嵌入式数据库，离线缓存任务流 |
| 存储 | 安全存储 | flutter_secure_storage | token、敏感信息加密存储 |
| UI | 动画 | flutter_animate | 声明式动画，任务状态切换、卡片出现等 |
| UI | 下拉刷新 | pull_to_refresh_flutter3 | 任务列表刷新 |
| 推送 | 移动推送 | firebase_messaging (FCM) + APNs | 离线推送（待确认、失败、主动提醒） |
| 权限 | 权限管理 | permission_handler | 麦克风、相机、相册权限统一管理 |

### 2.2 后端服务（Go）

| 组件 | 选型 | 理由 |
|------|------|------|
| 语言 | Go 1.23+ | 高并发、编译快、部署单二进制、goroutine 天然适合 Agent 并行调度 |
| HTTP | net/http (Go 1.22 路由) | 标准库原生支持 `{id}` 路径参数，零依赖 |
| WebSocket | gorilla/websocket | 成熟稳定、社区标准 |
| 数据库 | pgx/v5 + pgxpool | 高性能 PostgreSQL 驱动，连接池内置 |
| 认证 | golang-jwt/jwt/v5 | JWT 签发与校验 |
| 日志 | log/slog (标准库) | 结构化 JSON 日志，Go 1.21+ 内置 |
| 容器化 | 多阶段 Dockerfile | 最终镜像 ~15MB Alpine |

### 2.3 AI / Agent

| 组件 | 选型 | 理由 |
|------|------|------|
| 大模型 | Claude API (Anthropic) | 多模态（文字+图片）、tool use、最适合 Agent |
| 语音转写 | Whisper large-v3 (API) | 开源、中文效果好、Groq/Replicate 可托管 |
| Agent 协议 | Claude tool_use + 自研编排 | 直接用 Claude 原生 tool use 实现 Agent Teams |
| Embedding | text-embedding-3-small (OpenAI) | 记忆向量化、语义搜索 |
| TTS (V0.2+) | 讯飞 / Azure TTS / OpenAI TTS | 结果播报 |

### 2.4 数据与基础设施

| 组件 | 选型 | 理由 |
|------|------|------|
| 主数据库 | PostgreSQL 16 | 结构化数据 + pgvector 扩展 |
| 缓存/队列 | Redis 7 | BullMQ 后端、会话缓存、在线状态 |
| 向量索引 | pgvector | 与 PG 同库，运维简单 |
| 文件存储 | 阿里云 OSS / AWS S3 | 音频、图片、生成的文档 |
| 容器化 | Docker + Docker Compose | 开发/部署一致 |
| CI/CD | GitHub Actions | 自动化构建、测试、部署 |
| 监控 | Grafana + Prometheus | 服务指标、API 延迟、Agent 执行时长 |

## 三、Flutter 客户端详细设计

### 3.1 项目结构

```
app/
├── lib/
│   ├── main.dart                         # 入口
│   ├── app.dart                          # MaterialApp + 路由 + Provider scope
│   │
│   ├── core/                             # 基础设施
│   │   ├── config/
│   │   │   ├── env.dart                  # 环境变量
│   │   │   └── api_config.dart           # API 地址
│   │   ├── network/
│   │   │   ├── api_client.dart           # Dio 封装（拦截器、token、错误处理）
│   │   │   ├── socket_client.dart        # WebSocket 封装（连接、重连、事件分发）
│   │   │   └── api_exception.dart        # 统一异常
│   │   ├── storage/
│   │   │   ├── local_db.dart             # Isar 初始化
│   │   │   └── secure_storage.dart       # 安全存储
│   │   ├── audio/
│   │   │   ├── audio_recorder.dart       # 录音控制（开始、停止、文件路径）
│   │   │   └── audio_player.dart         # TTS 播放
│   │   ├── theme/
│   │   │   ├── app_theme.dart            # 主题定义
│   │   │   ├── app_colors.dart           # 颜色
│   │   │   └── app_typography.dart       # 字体
│   │   └── utils/
│   │       ├── permissions.dart          # 权限申请
│   │       └── file_utils.dart           # 文件处理
│   │
│   ├── features/                         # 按功能模块组织
│   │   ├── auth/                         # 认证
│   │   │   ├── data/
│   │   │   │   ├── auth_api.dart
│   │   │   │   └── auth_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── auth_repository.dart
│   │   │   │   └── user_entity.dart
│   │   │   └── presentation/
│   │   │       ├── login_screen.dart
│   │   │       └── auth_provider.dart
│   │   │
│   │   ├── command/                      # 指令输入（核心）
│   │   │   ├── data/
│   │   │   │   ├── command_api.dart       # 指令发送 API
│   │   │   │   └── command_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── command_entity.dart    # 指令实体
│   │   │   │   └── command_repository.dart
│   │   │   └── presentation/
│   │   │       ├── command_screen.dart    # 指令主屏
│   │   │       ├── command_provider.dart  # 状态管理
│   │   │       └── widgets/
│   │   │           ├── voice_record_button.dart   # 按住说话按钮
│   │   │           ├── text_input_bar.dart         # 文字输入栏
│   │   │           ├── image_attach_button.dart    # 图片附件
│   │   │           └── input_preview.dart          # 输入预览
│   │   │
│   │   ├── task/                         # 任务流
│   │   │   ├── data/
│   │   │   │   ├── task_api.dart
│   │   │   │   ├── task_cache.dart        # Isar 离线缓存
│   │   │   │   └── task_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── task_entity.dart
│   │   │   │   ├── sub_task_entity.dart
│   │   │   │   ├── result_card_entity.dart
│   │   │   │   └── task_repository.dart
│   │   │   └── presentation/
│   │   │       ├── task_list_screen.dart
│   │   │       ├── task_detail_screen.dart
│   │   │       ├── task_list_provider.dart
│   │   │       ├── task_detail_provider.dart
│   │   │       └── widgets/
│   │   │           ├── task_card.dart              # 任务卡片
│   │   │           ├── task_status_badge.dart      # 状态标签
│   │   │           ├── sub_task_list.dart          # 子任务列表
│   │   │           ├── result_card.dart            # 结果卡片
│   │   │           ├── confirmation_card.dart      # 确认卡片
│   │   │           ├── progress_indicator.dart     # 执行进度
│   │   │           └── follow_up_input.dart        # 追问输入
│   │   │
│   │   ├── onboarding/                   # 初始化引导
│   │   │   └── presentation/
│   │   │       ├── onboarding_screen.dart
│   │   │       └── onboarding_provider.dart
│   │   │
│   │   └── realtime/                     # 实时推送
│   │       ├── data/
│   │       │   └── socket_event_handler.dart
│   │       └── presentation/
│   │           └── realtime_provider.dart  # WebSocket 全局 Provider
│   │
│   └── router/
│       └── app_router.dart               # go_router 路由定义
│
├── assets/
│   ├── icons/
│   ├── images/
│   └── animations/                       # Lottie 动画（录音波形等）
│
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
│
├── pubspec.yaml
├── analysis_options.yaml
└── l10n/                                 # 国际化
    ├── app_zh.arb
    └── app_en.arb
```

### 3.2 核心组件设计

#### A. 按住说话按钮 (VoiceRecordButton)

这是产品最核心的交互组件。

```dart
// 状态定义
enum RecordingState {
  idle,        // 等待按下
  recording,   // 录音中
  uploading,   // 上传中
  processing,  // 服务端处理中
}

// 交互行为
// - GestureDetector.onLongPressStart → 开始录音
// - GestureDetector.onLongPressEnd   → 停止录音 → 上传
// - GestureDetector.onLongPressMoveUpdate → 上滑取消
// - 录音过程中显示波形动画 + 时长
// - 录音时长 < 1s → 提示"说话时间太短"
// - 录音时长 > 120s → 自动停止
```

视觉设计要求：
- 默认态：大圆形按钮，占据屏幕底部中心
- 按下态：按钮放大 + 脉冲动画 + 声波指示
- 上滑取消：按钮变红 + 提示"松开取消"
- 上传/处理中：按钮缩小 + 加载动画

#### B. WebSocket 实时通信 (SocketClient)

```dart
// 核心职责：
// 1. 建立连接、自动重连（指数退避）
// 2. 接收服务端推送事件
// 3. 解析事件类型，分发给对应 Provider
// 4. 离线重连后自动拉取未读事件

// 事件类型（与后端对齐）
sealed class ServerEvent {
  factory ServerEvent.fromJson(Map<String, dynamic> json);
}

class TaskCreatedEvent extends ServerEvent { ... }
class TaskUnderstandingEvent extends ServerEvent { ... }
class TaskProgressEvent extends ServerEvent { ... }
class TaskConfirmationNeededEvent extends ServerEvent { ... }
class TaskCompletedEvent extends ServerEvent { ... }
class TaskFailedEvent extends ServerEvent { ... }
class ProactiveAlertEvent extends ServerEvent { ... }
```

使用 Riverpod StreamProvider 全局监听：

```dart
final socketEventsProvider = StreamProvider<ServerEvent>((ref) {
  final socket = ref.watch(socketClientProvider);
  return socket.eventStream;
});

// 各 feature 的 Provider 监听并过滤自己关心的事件
final taskListProvider = AsyncNotifierProvider<TaskListNotifier, List<Task>>(() {
  // 内部监听 socketEventsProvider，按 taskId 更新状态
});
```

#### C. 任务卡片 (TaskCard)

根据任务状态展示不同 UI：

| 状态 | 展示内容 |
|------|---------|
| understanding | 原始指令 + "正在理解..." + 脉冲动画 |
| waiting_confirm | 理解摘要 + 确认内容 + 确认/取消按钮 |
| executing | 理解摘要 + 当前步骤 + 进度条 |
| completed | 理解摘要 + 结果卡片（可展开） |
| failed | 理解摘要 + 失败原因 + 重试按钮 |
| cancelled | 理解摘要 + "已取消" |

#### D. 离线缓存策略

使用 Isar 做本地缓存：

- 打开 App 时先展示本地缓存的任务列表，同时请求服务端最新数据
- WebSocket 推送的状态变更同步写入本地
- 无网络时展示本地数据，标注"离线模式"
- 恢复网络后自动同步

### 3.3 路由定义

```dart
// 3 个核心页面 + 1 个引导页 + 1 个登录页
final appRouter = GoRouter(
  routes: [
    // 主页（指令输入 + 任务流合一）
    GoRoute(
      path: '/',
      builder: (_, __) => const CommandScreen(),
    ),
    // 任务详情
    GoRoute(
      path: '/task/:taskId',
      builder: (_, state) => TaskDetailScreen(
        taskId: state.pathParameters['taskId']!,
      ),
    ),
    // 登录
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    // 初始化引导
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
  ],
  redirect: (context, state) {
    // 未登录 → /login
    // 已登录未初始化 → /onboarding
    // 已初始化 → /
  },
);
```

### 3.4 主屏布局（CommandScreen）

```
┌──────────────────────────────────┐
│  顶部栏（极简：Logo + 状态指示）   │
├──────────────────────────────────┤
│                                  │
│  任务流列表                       │
│  ┌────────────────────────────┐  │
│  │ TaskCard (executing)       │  │
│  ├────────────────────────────┤  │
│  │ TaskCard (waiting_confirm) │  │
│  ├────────────────────────────┤  │
│  │ TaskCard (completed)       │  │
│  ├────────────────────────────┤  │
│  │ ...                        │  │
│  └────────────────────────────┘  │
│                                  │
├──────────────────────────────────┤
│  底部输入区                       │
│  ┌──────┬────────────┬────────┐  │
│  │ 图片  │  文字输入    │ 发送   │  │
│  └──────┴────────────┴────────┘  │
│         ┌──────────────┐         │
│         │  按住说话      │         │
│         │  (大圆形按钮)  │         │
│         └──────────────┘         │
└──────────────────────────────────┘
```

指令输入和任务流合在一个屏幕。管理者打开 App 就能：
- 看到正在进行的任务
- 直接发新指令
- 对待确认任务做决策

## 四、后端服务详细设计

### 4.1 项目结构

```
server/
├── cmd/
│   └── server/
│       └── main.go                  # 入口：路由注册、启动 HTTP + WebSocket
│
├── internal/
│   ├── config/
│   │   └── config.go                # 环境变量加载
│   ├── db/
│   │   └── db.go                    # pgx 连接池 + 自动迁移
│   ├── handler/                     # HTTP Handler
│   │   ├── auth.go                  # POST /api/auth/login
│   │   ├── commands.go              # POST /api/commands + follow-up
│   │   ├── tasks.go                 # GET/POST /api/tasks/**
│   │   ├── users.go                 # 用户画像/规则
│   │   └── health.go                # GET /health
│   ├── middleware/
│   │   └── auth.go                  # JWT 认证中间件
│   ├── ws/
│   │   └── hub.go                   # WebSocket 连接管理 + 推送
│   ├── ai/                          # AI 相关（后续填充）
│   │   ├── claude.go
│   │   ├── whisper.go
│   │   └── prompts.go
│   ├── service/                     # 业务逻辑（后续填充）
│   │   ├── understanding.go
│   │   ├── orchestrator.go
│   │   ├── runner.go
│   │   └── upload.go
│   ├── tool/                        # Agent 工具（后续填充）
│   │   ├── registry.go
│   │   ├── task_item.go
│   │   ├── document.go
│   │   ├── memory.go
│   │   └── reminder.go
│   ├── queue/                       # 异步任务（后续填充）
│   │   └── worker.go
│   └── model/                       # 数据模型
│       ├── task.go
│       ├── user.go
│       └── event.go
│
├── go.mod
├── go.sum
└── Dockerfile
│       ├── agent.ts
│       ├── tool.ts
│       └── push_event.ts
│
├── drizzle.config.ts               # Drizzle 配置
├── docker-compose.yml              # PG + Redis
├── Dockerfile
├── package.json
└── tsconfig.json
```

### 4.2 理解层 System Prompt

```typescript
function buildUnderstandingPrompt(context: UserContext): string {
  return `
你是一位管理者的 AI 参谋长。你的唯一职责是：
准确理解管理者的指令，并转化为可执行的任务计划。

## 管理者信息
角色：${context.profile.role}
职责：${context.profile.responsibilities}
偏好：${context.profile.preferences}

## 管理者的规则
${context.rules.map(r => `- ${r.text}`).join('\n')}

## 当前正在进行的任务
${context.activeTasks.map(t => `- [${t.status}] ${t.understanding}`).join('\n')}

## 近期历史（供指代消解）
${context.recentHistory.map(h => `- ${h.input} → ${h.understanding}`).join('\n')}

## 相关记忆
${context.relevantMemories.map(m => `- ${m.content}`).join('\n')}

## 你的输出
严格返回以下 JSON（不要附加其他内容）：
{
  "understanding": "用一句管理者能看懂的话描述你的理解",
  "execution_plan": {
    "steps": [
      {
        "description": "步骤描述",
        "tools": ["需要的工具名"],
        "can_parallel": false
      }
    ],
    "requires_confirmation": false,
    "confirmation_message": "需要确认时展示的内容"
  },
  "risk_level": "low | medium | high",
  "intent_type": "goal | focus | rule | task",
  "related_task_id": null
}

## 风险判断
- 读取/整理/分析/生成/提醒 → low
- 涉及通知他人/修改数据/触发外部动作 → medium
- 大范围影响/不可逆/涉及敏感信息 → high
- 管理者自定义规则优先级高于默认规则
`;
}
```

### 4.3 Agent Runner 核心逻辑

```typescript
class AgentRunner {
  private maxRounds = 10;
  private timeoutMs = 60_000;

  async run(task: SubTask, tools: Tool[]): Promise<AgentResult> {
    const messages: Message[] = [
      { role: 'user', content: task.description }
    ];

    for (let round = 0; round < this.maxRounds; round++) {
      const response = await this.claude.messages.create({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 4096,
        system: this.buildAgentPrompt(task),
        messages,
        tools: this.toolRegistry.toClaudeFormat(tools),
      });

      // 如果模型返回 end_turn → 执行完成
      if (response.stop_reason === 'end_turn') {
        return this.extractResult(response);
      }

      // 如果模型返回 tool_use → 执行工具
      if (response.stop_reason === 'tool_use') {
        const toolResults = await this.executeToolCalls(
          response.content, task.context
        );

        // 每执行一个工具就推送进展
        await this.pushService.sendProgress(task.taskId, {
          step: task.description,
          message: this.summarizeToolResults(toolResults),
        });

        // 将工具结果加入上下文，继续循环
        messages.push({ role: 'assistant', content: response.content });
        messages.push({ role: 'user', content: toolResults });
      }
    }

    throw new AgentTimeoutError('Exceeded max rounds');
  }
}
```

### 4.4 API 接口定义

```
POST   /api/auth/sms-code           # 发送验证码
POST   /api/auth/login               # 验证码登录

POST   /api/commands                  # 发送指令（multipart: text, audio, images）
POST   /api/commands/:id/follow-up    # 追问/补充

GET    /api/tasks                     # 任务列表（?status=&page=&limit=）
GET    /api/tasks/:id                 # 任务详情（含子任务、执行日志）
POST   /api/tasks/:id/confirm         # 确认执行
POST   /api/tasks/:id/cancel          # 取消/叫停
POST   /api/tasks/:id/retry           # 重试失败任务

GET    /api/profile                   # 获取用户画像
PUT    /api/profile                   # 更新用户画像
GET    /api/rules                     # 获取规则列表
DELETE /api/rules/:id                 # 删除规则

WebSocket /ws                         # 实时推送通道
  → 连接时发送 { type: 'auth', token: '...' }
  ← 服务端推送 ServerEvent 流
```

## 五、数据模型

```sql
-- 用户
CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone         VARCHAR(20) UNIQUE NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 用户画像
CREATE TABLE user_profiles (
  user_id       UUID PRIMARY KEY REFERENCES users(id),
  profile       JSONB NOT NULL DEFAULT '{}',
  initialized   BOOLEAN DEFAULT FALSE,
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 用户规则
CREATE TABLE user_rules (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id),
  rule_text     TEXT NOT NULL,
  rule_parsed   JSONB,
  active        BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 任务
CREATE TABLE tasks (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id),
  parent_task_id  UUID REFERENCES tasks(id),

  input_text      TEXT,
  input_audio_url TEXT,
  input_image_urls TEXT[],

  understanding   TEXT,
  execution_plan  JSONB,
  risk_level      VARCHAR(10),
  intent_type     VARCHAR(20),

  status          VARCHAR(20) NOT NULL DEFAULT 'created',
  result          JSONB,
  error           TEXT,

  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 子任务
CREATE TABLE sub_tasks (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id       UUID NOT NULL REFERENCES tasks(id),
  step_index    INT NOT NULL,
  description   TEXT NOT NULL,
  status        VARCHAR(20) DEFAULT 'pending',
  result        JSONB,
  started_at    TIMESTAMPTZ,
  completed_at  TIMESTAMPTZ
);

-- 执行日志
CREATE TABLE execution_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id       UUID NOT NULL REFERENCES tasks(id),
  sub_task_id   UUID REFERENCES sub_tasks(id),
  event_type    VARCHAR(50) NOT NULL,
  payload       JSONB,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 长期记忆
CREATE TABLE memories (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id),
  task_id       UUID REFERENCES tasks(id),
  content       TEXT NOT NULL,
  embedding     vector(1536),
  memory_type   VARCHAR(20),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 定时任务
CREATE TABLE scheduled_jobs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id),
  source_text   TEXT,
  job_type      VARCHAR(20) NOT NULL,
  schedule      VARCHAR(100),
  context       JSONB,
  active        BOOLEAN DEFAULT TRUE,
  next_run_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 事项（Agent 创建的管理事项）
CREATE TABLE task_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id),
  source_task_id UUID REFERENCES tasks(id),
  title         TEXT NOT NULL,
  description   TEXT,
  assignee      TEXT,
  priority      VARCHAR(10) DEFAULT 'medium',
  status        VARCHAR(20) DEFAULT 'open',
  deadline      TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_tasks_user_status ON tasks(user_id, status);
CREATE INDEX idx_tasks_user_created ON tasks(user_id, created_at DESC);
CREATE INDEX idx_sub_tasks_task ON sub_tasks(task_id);
CREATE INDEX idx_logs_task ON execution_logs(task_id, created_at);
CREATE INDEX idx_memories_user ON memories(user_id);
CREATE INDEX idx_memories_embedding ON memories
  USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX idx_task_items_user ON task_items(user_id, status);
CREATE INDEX idx_scheduled_next ON scheduled_jobs(next_run_at)
  WHERE active = TRUE;
```

## 六、关键流程时序

### 6.1 语音指令完整流程

```
管理者         Flutter App        API Gateway     指令服务        理解层          执行层         推送服务
  │              │                  │              │              │              │              │
  │─ 按住说话 ──►│                  │              │              │              │              │
  │              │ 录音 (record)    │              │              │              │              │
  │─ 松开 ──────►│                  │              │              │              │              │
  │              │─ POST /commands ─►│─────────────►│              │              │              │
  │              │  (audio file)    │              │              │              │              │
  │              │                  │              │─ STT ────────►              │              │
  │              │                  │              │─ 创建 task ──►              │              │
  │              │◄─── WS: task_created ───────────┼──────────────┼──────────────┼──── push ◄───│
  │◄─ "已收到" ──│                  │              │              │              │              │
  │              │                  │              │   加载上下文   │              │              │
  │              │                  │              │   调用 Claude  │              │              │
  │              │                  │              │              │              │              │
  │              │◄─── WS: task_understanding ─────┼──────────────┼──────────────┼──── push ◄───│
  │◄─"理解为…" ──│                  │              │              │              │              │
  │              │                  │              │──execution──►│              │              │
  │              │                  │              │   plan        │──创建子Agent──│              │
  │              │                  │              │              │  tool_use     │              │
  │              │                  │              │              │  循环执行     │              │
  │              │◄─── WS: task_progress ──────────┼──────────────┼──────────────┼──── push ◄───│
  │◄─"进展…" ────│                  │              │              │              │              │
  │              │                  │              │              │  执行完成     │              │
  │              │◄─── WS: task_completed ─────────┼──────────────┼──────────────┼──── push ◄───│
  │◄─ 结果卡片 ──│                  │              │              │              │              │
```

### 6.2 图片 + 语音混合指令

```
管理者拍照 → 按住说话 → 松开
  │
  ▼
Flutter App 组装 multipart:
  - audio: recording.aac
  - images: [photo.jpg]
  │
  ▼
POST /api/commands (multipart/form-data)
  │
  ▼
指令服务：
  1. 上传音频到 OSS → audio_url
  2. 上传图片到 OSS → image_urls[]
  3. 调用 Whisper → transcribed_text
  4. 创建 task 记录
  5. 入队
  │
  ▼
理解层：
  调用 Claude API，messages 包含：
  - text: transcribed_text
  - image: image_urls（Claude Vision 自动识别图片内容）
  │
  ▼
后续流程同 6.1
```

## 七、开发计划

### 第一阶段：V0.1 — 跑通核心闭环（5 周）

**目标**：管理者发一句话 → 系统理解 → 单 Agent 执行 → 返回结果。

#### 第 1 周：项目搭建

**后端**
- [ ] 初始化 Node.js + Fastify + TypeScript 项目
- [ ] Docker Compose（PostgreSQL + Redis）
- [ ] Drizzle ORM 配置 + 建表迁移
- [ ] 基础路由骨架（health, auth, commands, tasks）
- [ ] 基础认证中间件（JWT）
- [ ] WebSocket 服务端（ws 库 + 连接管理）

**Flutter**
- [ ] 初始化 Flutter 项目（flutter create）
- [ ] 依赖安装（riverpod, dio, go_router, freezed, record, image_picker...）
- [ ] core 层搭建（ApiClient, SocketClient, theme, env）
- [ ] 路由配置（go_router）
- [ ] 空壳页面（CommandScreen, TaskListScreen, TaskDetailScreen, LoginScreen）

#### 第 2 周：输入层

**后端**
- [ ] POST /api/commands 接口（multipart 接收 text + audio）
- [ ] 集成 Whisper API（语音转写）
- [ ] 文件上传到 OSS
- [ ] 创建任务记录 → WebSocket 推送 task_created

**Flutter**
- [ ] 登录页（手机号 + 验证码）
- [ ] VoiceRecordButton 组件（按住录音、松开停止、上滑取消、波形动画）
- [ ] TextInputBar 组件（文字输入 + 发送）
- [ ] 权限申请（麦克风）
- [ ] 指令发送（调用 API、上传音频）
- [ ] 即时反馈展示（收到 task_created 事件 → 显示"已收到"）

#### 第 3 周：理解层 + 执行层

**后端**
- [ ] 理解层服务：构造上下文 + 调用 Claude API → 结构化输出
- [ ] System Prompt 第一版
- [ ] BullMQ 队列：指令 → 理解 worker → 执行 worker
- [ ] AgentOrchestrator + AgentRunner（单 Agent 执行）
- [ ] 工具注册中心 + 第一批工具：
  - create_task_item
  - generate_document
  - store_memory
- [ ] 执行日志写入
- [ ] WebSocket 推送：task_understanding / task_progress / task_completed / task_failed

**Flutter**
- [ ] WebSocket 全局 Provider（连接、重连、事件分发）
- [ ] 任务流视图（TaskCard 列表 + 按状态展示）
- [ ] 接收并展示理解结果（"我理解你要做的是…"）
- [ ] 接收并展示执行进展
- [ ] 结果卡片基础展示

#### 第 4 周：任务详情 + 联调

**后端**
- [ ] GET /api/tasks（分页、按状态筛选）
- [ ] GET /api/tasks/:id（含子任务、执行日志）
- [ ] 异常处理（Agent 超时、工具失败 → 重试 → 降级）
- [ ] Prompt 调优（提高理解准确率）

**Flutter**
- [ ] 任务详情页（理解结果 + 子任务列表 + 执行日志 + 最终结果）
- [ ] 任务卡片状态切换动画
- [ ] 错误状态展示（失败原因 + 重试按钮）
- [ ] 下拉刷新 + 无限滚动

#### 第 5 周：端到端打磨

- [ ] 全链路联调（语音输入 → 转写 → 理解 → Agent 执行 → 结果展示）
- [ ] 弱网环境测试 + WebSocket 断线重连
- [ ] UI 打磨（加载态、空态、过渡动画）
- [ ] 音频录制参数调优（采样率、编码格式、文件大小）
- [ ] 基础错误边界和 Crash 上报
- [ ] 内部 Demo 演示

**交付物**：可运行的 V0.1 Demo，核心闭环验证通过。

### 第二阶段：V0.2 — 多模态 + Agent Teams + 确认（4 周）

#### 第 6 周：图片输入

**后端**
- [ ] POST /api/commands 支持 images 字段
- [ ] 图片上传 + 压缩存储
- [ ] 理解层支持图片（Claude Vision：message 中嵌入 image_url）
- [ ] 端到端验证（拍白板 → 理解 → 执行）

**Flutter**
- [ ] ImageAttachButton 组件（拍照 / 相册选择）
- [ ] 图片预览和删除
- [ ] 混合输入（语音 + 图片同时发送）
- [ ] InputPreview 组件（已选图片 + 录音状态的统一预览）

#### 第 7 周：Agent Teams

**后端**
- [ ] AgentOrchestrator 支持多子 Agent 并行调度
- [ ] 子 Agent 间结果传递（前序 Agent 结果作为后续 Agent 上下文）
- [ ] 增加工具：list_task_items, update_task_item, search_memory
- [ ] 流式进展推送（每个子 Agent 完成即推送）

**Flutter**
- [ ] 子任务树展示（任务详情中的子任务列表 + 各自状态）
- [ ] 子任务执行过程流式展示
- [ ] 进度指示器（多步骤进度条）

#### 第 8 周：确认机制 + 追问

**后端**
- [ ] 风险判断 → 待确认状态流转
- [ ] POST /api/tasks/:id/confirm + cancel
- [ ] POST /api/commands/:id/follow-up（追问/补充）
- [ ] 追问时加载父任务完整上下文
- [ ] Prompt 调优（风险判断准确率）

**Flutter**
- [ ] ConfirmationCard 组件（确认内容 + 确认/取消按钮）
- [ ] 追问输入（任务详情页内的 FollowUpInput）
- [ ] 叫停操作（执行中任务的取消按钮）

#### 第 9 周：联调打磨

- [ ] 复杂指令场景测试（图片 + 语音 → 多 Agent → 确认 → 执行）
- [ ] 确认流程 UX 打磨
- [ ] 任务状态实时刷新稳定性
- [ ] 性能测试（多任务并发）

**交付物**：支持图片、多 Agent、确认机制的完整版本。

### 第三阶段：V0.3 — 记忆与持续推进（4 周）

#### 第 10 周：记忆系统

**后端**
- [ ] 用户画像自动提取（从指令和结果中持续丰富）
- [ ] 长期记忆存储 + Embedding 生成
- [ ] pgvector 语义搜索
- [ ] 上下文构造优化（画像 + 工作记忆 + 相关长期记忆）
- [ ] 指代消解验证（"上次那个事""跟之前一样"）

#### 第 11 周：规则与调度

**后端**
- [ ] 规则识别（大模型从指令中识别规则类意图）
- [ ] 规则持久化 + 注入理解层上下文
- [ ] BullMQ 定时任务框架
- [ ] 定时触发 → 大模型评估 → 推送结果

**Flutter**
- [ ] 主动推送展示（非用户指令触发的卡片出现在任务流中）
- [ ] 推送通知集成（FCM + APNs）

#### 第 12 周：Onboarding

**后端**
- [ ] 初始化对话流程（多轮对话提取画像）
- [ ] 画像 → user_profiles 存储

**Flutter**
- [ ] OnboardingScreen（对话式引导，非表单）
- [ ] 画像初始化完成后跳转主页

#### 第 13 周：整体优化

- [ ] 全链路 Prompt 优化（理解准确率、风险判断、规则执行）
- [ ] 响应时延优化（理解和执行并行、流式推送）
- [ ] 离线缓存完善（Isar 本地缓存 + 增量同步）
- [ ] 内存和电量优化

**交付物**：有记忆、有规则、能主动推进的产品。

### 第四阶段：V0.4 — 外部工具 + 产品化（4 周）

#### 第 14-15 周：外部工具集成

- [ ] 工具扩展框架（外部工具适配器模式）
- [ ] 接入日历（Google Calendar / 企业微信）
- [ ] 接入 IM 通知（企业微信 / 飞书 / 钉钉 webhook）
- [ ] 接入邮件（SMTP）

#### 第 16-17 周：产品化

- [ ] 安全加固（API 鉴权、数据加密、敏感操作审计）
- [ ] 监控和告警（Grafana + Prometheus）
- [ ] UI 全面打磨（动画、手势、微交互）
- [ ] 性能优化（启动速度、大列表、长连接稳定性）
- [ ] 自动化测试（单元 + Widget + 集成）
- [ ] App Store / Google Play 上架准备（签名、截图、审核材料）

**交付物**：可对外发布的 V1.0。

## 八、关键技术风险与应对

| 风险 | 影响 | 应对 |
|------|------|------|
| Claude API 延迟（2-8s） | 用户等待感差 | 立即反馈"已收到" → 理解完反馈 → 流式推送进展 |
| 语音转写不准 | 指令理解错误 | 展示转写文本供确认；短期用 Whisper，后续可换讯飞/Deepgram |
| Agent tool_use 死循环 | 任务卡住、资源浪费 | 最大 10 轮 + 60s 超时 + 自动终止 |
| 上下文窗口超限 | 理解质量下降 | 分层记忆 + 摘要压缩 + 只注入 top-K 相关记忆 |
| WebSocket 断连 | 状态丢失 | 指数退避重连 + 重连后增量同步 + 本地 Isar 缓存兜底 |
| Flutter 原生能力不足 | 录音/推送体验差 | 使用成熟 plugin（record, firebase_messaging）+ 必要时写 platform channel |
| 并发任务冲突 | 数据不一致 | 数据库事务 + 乐观锁 + 任务级队列隔离 |

## 九、里程碑总览

| 里程碑 | 周数 | 交付物 | 验证点 |
|--------|------|--------|--------|
| V0.1 | 第 1-5 周 | 语音/文字 → 理解 → 单 Agent → 结果 | 核心闭环跑通 |
| V0.2 | 第 6-9 周 | 图片 + Agent Teams + 确认 + 追问 | 复杂指令可执行 |
| V0.3 | 第 10-13 周 | 记忆 + 规则 + 持续推进 + Onboarding | 产品有记忆和主动性 |
| V0.4/V1.0 | 第 14-17 周 | 外部工具 + 安全 + 产品化 + 上架 | 可对外发布 |

总周期约 **17 周（4 个月）** 达到 V1.0。

## 十、环境与工具链

### 开发环境

```
Flutter SDK: 3.x (stable channel)
Dart SDK: 3.x
Node.js: 20 LTS
PostgreSQL: 16
Redis: 7
Docker Desktop
IDE: Cursor / VS Code + Flutter 插件
```

### Flutter 关键依赖（pubspec.yaml）

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 状态管理
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0

  # 路由
  go_router: ^14.0.0

  # 网络
  dio: ^5.4.0
  web_socket_channel: ^3.0.0

  # 代码生成
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0

  # 音频
  record: ^5.1.0
  just_audio: ^0.9.0

  # 图片
  image_picker: ^1.1.0
  flutter_image_compress: ^2.3.0

  # 本地存储
  isar: ^3.1.0
  flutter_secure_storage: ^9.2.0

  # UI
  flutter_animate: ^4.5.0
  lottie: ^3.1.0
  pull_to_refresh_flutter3: ^2.0.0
  cached_network_image: ^3.4.0

  # 推送
  firebase_messaging: ^15.0.0
  firebase_core: ^3.0.0

  # 权限
  permission_handler: ^11.3.0

  # 工具
  uuid: ^4.4.0
  intl: ^0.19.0
  logger: ^2.4.0
  path_provider: ^2.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  riverpod_generator: ^2.4.0
  flutter_lints: ^4.0.0
  mockito: ^5.4.0
  integration_test:
    sdk: flutter
```
