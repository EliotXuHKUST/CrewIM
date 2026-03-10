# 知知 — AI 时代的管理者指挥台

管理者发出任何指令（语音、文字、图片），大模型理解后交给 Agent Teams 执行，管理者只管发令和拍板。

知知是 **OpenClaw** 生态的原生 IM 通道 — 管理者与 AI Agent Team 之间的指挥界面。用户在 OpenClaw SaaS 平台上运行 Agent，知知作为 Channel 负责指令输入、任务管理与实时推送。

**核心循环**：`输入 → 大模型理解 → Agent Teams 执行 → 确认/结果`

## 架构总览

```
┌──────────────────────────────────────────────────────────┐
│            Flutter 客户端 (iOS)                            │
│                                                          │
│  Onboarding · 语音/文字/图片输入 · 富交互任务卡片           │
│  待拍板置顶 · 结果后续操作 · 补充一句 · 本地优先            │
└────────────────────────┬─────────────────────────────────┘
                         │ HTTPS + WebSocket
┌────────────────────────┼─────────────────────────────────┐
│               Go 服务端 (net/http)                        │
│                        │                                  │
│  ┌─ 认证层 ─────────────────────────────────────────┐    │
│  │  SMS 登录 · JWT (7天) · 自动续签 · 短信限流 · CORS │    │
│  └──────────────────────────────────────────────────┘    │
│  ┌─ 业务层 ─────────────────────────────────────────┐    │
│  │  Commands · Tasks · Sessions · Accounts · Rules   │    │
│  │  账号注销(全量级联删除) · 用户画像                   │    │
│  └──────────────────────────────────────────────────┘    │
│  ┌─ 理解层 ─────────────────────────────────────────┐    │
│  │  腾讯云 ASR 语音转写 · Claude 大模型意图理解        │    │
│  └──────────────────────────────────────────────────┘    │
│  ┌─ 执行层 ─────────────────────────────────────────┐    │
│  │  Agent Runner · 工具注册中心 · OpenClaw 路由       │    │
│  └──────────────────────────────────────────────────┘    │
│  ┌─ 推送层 ─────────────────────────────────────────┐    │
│  │  WebSocket Hub · 任务队列 (理解 + 执行 Worker)     │    │
│  └──────────────────────────────────────────────────┘    │
└────────────────────────┼─────────────────────────────────┘
                         │
┌────────────────────────┼─────────────────────────────────┐
│   PostgreSQL 16 (pgvector)  ·  Redis 7  ·  本地上传目录    │
└──────────────────────────────────────────────────────────┘
```

## 项目结构

```
.
├── app/                          # Flutter 客户端 (iOS)
│   ├── lib/
│   │   ├── main.dart             # 入口 — ZhiZhiApp, light-only, 竖屏锁定
│   │   ├── core/                 # 基础设施
│   │   │   ├── audio/            #   录音封装 (record)
│   │   │   ├── config/           #   API / WS 地址
│   │   │   ├── network/
│   │   │   │   ├── api_client    #   HTTP — 自动 401 续签, ApiException
│   │   │   │   ├── socket_client #   WebSocket — 自动重连, 指数退避
│   │   │   │   └── socket_manager#   事件分发 (全局 + 会话级)
│   │   │   ├── storage/
│   │   │   │   ├── local_database#   SQLite schema v2 (sessions, messages, tasks, sync_queue)
│   │   │   │   ├── auth_storage  #   SharedPreferences token/phone
│   │   │   │   └── *_dao         #   SessionDao, MessageDao, TaskDao, SyncQueueDao
│   │   │   ├── sync/             #   SyncEngine — 5s 轮询, 离线队列, 重试上限
│   │   │   └── theme/            #   AppColors, AppTheme (light-only), AppTypography
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   │   ├── auth_gate     #   Token检查 → Onboarding / Login / Chat
│   │   │   │   └── login_screen  #   手机号 + 验证码, 限流提示, 隐私声明
│   │   │   ├── onboarding/       #   3页引导 (说就行 / AI执行 / 看进展) + 跳过
│   │   │   ├── session/
│   │   │   │   ├── domain/       #   Session, Message (含 MessageType + metadata)
│   │   │   │   ├── data/         #   SessionRepository (local-first + task actions)
│   │   │   │   └── presentation/
│   │   │   │       ├── session_chat_screen  # 主屏 — 待拍板banner + 消息流 + 输入
│   │   │   │       └── widgets/
│   │   │   │           ├── chat_message_bubble  # 文本气泡 + 任务卡片分发
│   │   │   │           ├── task_cards           # 5种富卡片 + FollowUpInput
│   │   │   │           ├── scene_cards          # 空状态引导
│   │   │   │           └── nav_drawer           # 会话切换侧栏
│   │   │   ├── command/          #   ChatInputBar (语音/文字/图片)
│   │   │   ├── task/             #   TaskDetailScreen, TaskCard, ResultCard
│   │   │   └── settings/
│   │   │       ├── settings_screen    # 账号·AI服务·绑定账号·反馈·隐私·注销
│   │   │       └── account_edit_screen# 邮箱/公众号/小红书 凭据管理
│   │   └── router/               #   路由表
│   └── ios/
│       └── Runner/Info.plist      #   显示名"知知", 竖屏, 权限声明, 加密声明
│
├── server/                        # Go 服务端
│   ├── cmd/server/main.go         # 入口 — 路由注册, 中间件链, 服务初始化
│   ├── internal/
│   │   ├── ai/                    #   Claude (OpenRouter/Anthropic), Whisper, Prompts
│   │   ├── asr/                   #   腾讯云 ASR + Mock
│   │   ├── config/                #   环境变量加载
│   │   ├── crypto/                #   AES 加密 (账号凭据)
│   │   ├── db/                    #   pgx 连接池 + Schema + 迁移
│   │   ├── handler/
│   │   │   ├── auth               #   登录 · 续签 · 注销(级联删除11表)
│   │   │   ├── commands           #   创建指令 · 追问 (继承session_id)
│   │   │   ├── tasks              #   列表(session_id筛选) · 详情 · 确认/取消/重试
│   │   │   ├── sessions           #   CRUD
│   │   │   ├── accounts           #   第三方账号 CRUD (凭据AES加密)
│   │   │   ├── users              #   Profile · Rules
│   │   │   └── health             #   健康检查
│   │   ├── middleware/
│   │   │   ├── auth               #   JWT 解析 + 签发 (7天有效期)
│   │   │   └── cors               #   CORS (允许所有来源)
│   │   ├── model/                 #   Task, SubTask, User, PushEvent 等
│   │   ├── openclaw/              #   OpenClaw Gateway WebSocket 客户端
│   │   ├── queue/                 #   TaskQueue (理解Worker + 执行Worker)
│   │   ├── service/
│   │   │   ├── understanding      #   Claude 意图理解 → 执行计划
│   │   │   ├── orchestrator       #   任务编排 → 子任务分发
│   │   │   ├── runner             #   Agent循环 (max 10 rounds, 60s timeout)
│   │   │   └── upload             #   文件保存
│   │   ├── sms/                   #   验证码 + 限流 (60s/次, 5次/时)
│   │   ├── tool/                  #   工具注册 (文档·邮件·提醒·记忆·任务项)
│   │   └── ws/                    #   WebSocket Hub (多连接, JWT认证)
│   ├── go.mod
│   └── Dockerfile
│
├── docs/                          # 设计文档
│   ├── prd.md                     #   产品需求文档
│   ├── feature-list.md            #   功能清单与分期
│   ├── technical-architecture.md  #   技术架构
│   ├── design-guidelines.md       #   设计规范
│   └── voice-interaction-loop.md  #   语音交互闭环
│
└── docker-compose.yml             # PostgreSQL (pgvector) + Redis
```

## 快速开始

### 前置条件

- Go 1.22+
- Flutter 3.x (Dart 3.8+)
- Docker & Docker Compose
- 腾讯云 SMS/ASR 密钥（或使用 mock 模式）
- OpenRouter 或 Anthropic API Key

### 1. 启动基础设施

```bash
docker compose up -d
```

PostgreSQL (pgvector) 监听 `5433`（宿主机），Redis 监听 `6379`。

### 2. 配置并启动服务端

```bash
cd server
cp .env.example .env   # 填入 API Key 等配置
go run ./cmd/server
```

服务端默认监听 `:3000`，自动执行数据库迁移。

<details>
<summary>环境变量一览</summary>

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PORT` | `3000` | 服务端口 |
| `DATABASE_URL` | `postgres://...localhost:5433/command_center` | PostgreSQL 连接串（docker-compose 映射到 5433） |
| `REDIS_URL` | `redis://localhost:6379` | Redis 地址 |
| `JWT_SECRET` | `dev-secret-change-me` | JWT 签名密钥 (生产环境必须替换) |
| `OPENROUTER_API_KEY` | — | OpenRouter API Key |
| `ANTHROPIC_API_KEY` | — | Anthropic API Key (备选) |
| `SMS_PROVIDER` | `mock` | `mock` / `tencent` |
| `ASR_PROVIDER` | `mock` | `mock` / `tencent` |
| `TENCENT_SECRET_ID` | — | 腾讯云 SecretId |
| `TENCENT_SECRET_KEY` | — | 腾讯云 SecretKey |
| `TENCENT_SMS_SDK_APP_ID` | — | 腾讯云 SMS App ID |
| `TENCENT_SMS_SIGN_NAME` | — | 腾讯云 SMS 签名 |
| `TENCENT_SMS_TEMPLATE_ID` | — | 腾讯云 SMS 模板 ID |
| `ACCOUNT_ENCRYPT_KEY` | `dev-encrypt-key-change-me-32chr` | 账号凭据 AES 密钥 (32字符) |
| `UPLOAD_DIR` | `./uploads` | 音频/图片上传目录 |

</details>

### 3. 启动 Flutter 客户端

```bash
cd app
flutter pub get
flutter run
```

生产环境构建时通过 `--dart-define` 注入 API 地址：

```bash
flutter build ios \
  --dart-define=API_BASE_URL=https://api.yourserver.com \
  --dart-define=WS_BASE_URL=wss://api.yourserver.com/ws
```

## API 端点

### 认证

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/auth/sms-code` | 发送验证码（限流：60s/次，5次/时） |
| `POST` | `/api/auth/login` | 手机号 + 验证码登录，返回 JWT |
| `POST` | `/api/auth/refresh` | JWT 续签 🔒 |
| `DELETE` | `/api/auth/account` | 注销账号，级联删除所有数据 🔒 |

### 实时通信

| 方法 | 路径 | 说明 |
|------|------|------|
| `GET` | `/ws` | WebSocket（首条消息发 `{type:"auth", token:"..."}` 鉴权） |

### 指令与任务

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/commands` | 创建指令（支持 JSON 或 multipart 上传音频/图片）🔒 |
| `POST` | `/api/commands/{id}/follow-up` | 追问/补充（自动继承 session_id）🔒 |
| `GET` | `/api/tasks` | 任务列表（`?session_id` `?status` `?page` `?limit`）🔒 |
| `GET` | `/api/tasks/{id}` | 任务详情 + 子任务 🔒 |
| `POST` | `/api/tasks/{id}/confirm` | 确认待拍板任务 🔒 |
| `POST` | `/api/tasks/{id}/cancel` | 取消任务 🔒 |
| `POST` | `/api/tasks/{id}/retry` | 重试失败任务 🔒 |

### 会话 · 账号 · 用户

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/sessions` | 创建会话 🔒 |
| `GET` | `/api/sessions` | 会话列表 🔒 |
| `PUT` | `/api/sessions/{id}` | 更新会话标题 🔒 |
| `DELETE` | `/api/sessions/{id}` | 删除会话 🔒 |
| `GET/PUT` | `/api/profile` | 用户资料 🔒 |
| `CRUD` | `/api/accounts` | 第三方账号（邮箱/公众号/小红书）🔒 |
| `GET` | `/api/rules` | 管理规则列表 🔒 |
| `DELETE` | `/api/rules/{id}` | 删除规则 🔒 |

> 🔒 = 需要 `Authorization: Bearer <token>` 头

### WebSocket 推送事件

| 事件类型 | 触发时机 | 客户端处理 |
|---------|---------|-----------|
| `task_created` | 指令已接收 | 显示任务创建消息 |
| `task_understanding` | 理解完成 | 理解卡片 (灯泡图标) |
| `task_progress` | 执行步骤更新 | 进度卡片 (旋转动画) |
| `task_waiting_confirm` | 高风险需确认 | 确认卡片 (确认/取消按钮) + 待拍板 banner |
| `task_completed` | 执行完成 | 结果卡片 (复制/继续处理/转文档) |
| `task_failed` | 执行失败 | 错误卡片 (重试/补充信息) + AI 建议 |
| `session_updated` | 会话自动命名 | 更新侧栏标题 |

## Agent 工具

执行层通过工具注册中心调用以下能力，Claude 根据任务自动选择：

| 工具 | 说明 |
|------|------|
| `generate_document` | 生成文档、方案、简报、清单（Claude 驱动） |
| `send_email` | 使用用户绑定的邮箱 SMTP 发送邮件 |
| `store_memory` | 存储关键信息到长期记忆 |
| `search_memory` | 搜索历史记忆中的相关信息 |
| `set_reminder` | 设定一次性或周期性提醒（写入 scheduled_jobs） |
| `create_task_item` | 创建管理事项（待办、跟进任务） |
| `list_task_items` | 查询当前管理事项列表 |

## 技术栈

| 层级 | 选型 |
|------|------|
| 客户端 | Flutter 3.x · Dart · SQLite (local-first) · WebSocket |
| 服务端 | Go 1.22 · net/http (Go 1.22 路由) · pgx v5 · gorilla/websocket |
| 大模型 | Claude (OpenRouter / Anthropic 直连) · 腾讯云 ASR |
| 安全 | JWT (7天 + 自动续签) · SMS 限流 · CORS · AES 凭据加密 |
| 数据库 | PostgreSQL 16 (pgvector) · Redis 7 |
| 部署 | Docker · Docker Compose |

## 数据库 Schema

```
users                 1──N  sessions
  │                          │
  ├──1 user_profiles         ├──N tasks ──N sub_tasks
  ├──N user_rules            │           ──N execution_logs
  ├──N user_accounts         │
  ├──N memories              │
  ├──N task_items            │
  └──N scheduled_jobs        │
```

11 张表，`DELETE /api/auth/account` 全量级联删除。

## App Store 上架清单

| 要求 | 状态 |
|------|------|
| 账号注销 | ✅ 双重确认 + 服务端级联删除 |
| 隐私政策声明 | ✅ 登录页 + 设置页 |
| 权限用途描述 | ✅ 麦克风 / 相机 / 相册 |
| 加密合规声明 | ✅ `ITSAppUsesNonExemptEncryption = false` |
| App 显示名 | ✅ 知知 |
| 竖屏锁定 | ✅ Portrait only |
| 反馈入口 | ✅ 设置页意见反馈 |
| 引导页 | ✅ 3 页 Onboarding + 跳过 |

**上架前需额外完成：**

- [ ] 替换隐私政策和用户协议的实际 URL
- [ ] 配置 Apple Developer 证书 + Bundle Identifier
- [ ] 制作 App 图标 (1024x1024) 和 App Store 截图
- [ ] 配置生产 API 地址 (`--dart-define`)
- [ ] 切换腾讯云短信 (`SMS_PROVIDER=tencent`)
- [ ] 生产环境 `JWT_SECRET` 和 `ACCOUNT_ENCRYPT_KEY`

## 文档

- [产品需求文档 (PRD)](docs/prd.md)
- [功能清单与分期](docs/feature-list.md)
- [技术架构](docs/technical-architecture.md)
- [设计规范](docs/design-guidelines.md)
- [语音交互闭环](docs/voice-interaction-loop.md)

## License

Private — All rights reserved.
