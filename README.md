# CrewIM — OpenCrew 的 IM

**OpenCrew 的即时通讯与指挥界面**。管理者发出任何指令（语音、文字、图片），大模型理解后交给 Agent Teams 执行，管理者只管发令和拍板。

## 产品定位

不做 CRM/OA 插件，不做聊天助手，不做语音版企业 IM。

做 **OpenCrew** 生态下的 AI 时代原生管理者控制台 — 管理者和一支 AI Agent Team 之间的指挥界面。

> CrewIM 是 [OpenCrew](https://github.com/opencrew) 项目中的 IM 模块，负责指令输入、会话管理与实时推送。

**核心循环**：`输入 → 大模型理解 → Agent Teams 执行 → 确认/结果`

## 架构总览

```
┌────────────────────────────────────────────────┐
│           Flutter 客户端 (iOS / Android / Web)    │
│   语音录制 · 文字/图片输入 · 任务流 · 结果卡片      │
└──────────────────────┬─────────────────────────┘
                       │ HTTPS + WebSocket
┌──────────────────────┼─────────────────────────┐
│              Go 服务端 (net/http)                │
│                      │                          │
│   Auth ─ Commands ─ Tasks ─ Sessions ─ Accounts │
│      │                                          │
│   理解层: STT 转写 + 大模型意图理解                │
│      │                                          │
│   执行层: Agent Teams + 工具注册中心              │
│      │                                          │
│   推送层: WebSocket Hub (实时反馈)               │
└──────────────────────┼─────────────────────────┘
                       │
┌──────────────────────┼─────────────────────────┐
│   PostgreSQL (pgvector)  ·  Redis  ·  OSS       │
└────────────────────────────────────────────────┘
```

## 项目结构

```
.
├── app/                    # Flutter 客户端
│   └── lib/
│       ├── core/           # 基础设施
│       │   ├── audio/      #   录音 (record)
│       │   ├── network/    #   HTTP (手写) + WebSocket
│       │   ├── storage/    #   SQLite DAO (local-first)
│       │   ├── sync/       #   后台同步引擎
│       │   └── theme/      #   颜色 / 字体 / 主题
│       ├── features/       # 业务模块
│       │   ├── auth/       #   SMS 验证码登录
│       │   ├── command/    #   指令输入 (语音 + 文字)
│       │   ├── session/    #   会话列表 + 对话详情
│       │   ├── settings/   #   设置 + 账号管理
│       │   └── task/       #   任务详情 + 结果卡片
│       └── router/         # go_router 路由
│
├── server/                 # Go 服务端
│   ├── cmd/server/         # 入口
│   ├── internal/
│   │   ├── ai/             # Claude (OpenRouter) + Whisper
│   │   ├── asr/            # 语音转写 (腾讯云 ASR)
│   │   ├── config/         # 环境变量配置
│   │   ├── db/             # PostgreSQL 连接 + 迁移
│   │   ├── handler/        # HTTP handlers
│   │   ├── middleware/     # JWT 鉴权
│   │   ├── model/          # 数据模型
│   │   ├── openclaw/       # OpenClaw 集成
│   │   ├── queue/          # 任务队列
│   │   ├── service/        # 理解 + 编排 + 执行
│   │   ├── sms/            # 短信验证码 (腾讯云)
│   │   ├── tool/           # Agent 工具注册
│   │   └── ws/             # WebSocket Hub
│   └── Dockerfile
│
├── src/voice/              # 语音交互闭环 (TypeScript)
│   ├── types.ts            #   状态 / 事件 / 反馈类型
│   ├── state-machine.ts    #   状态流转函数
│   └── index.ts            #   导出
│
├── docs/                   # 设计文档
│   ├── prd.md              #   产品需求
│   ├── technical-architecture.md
│   ├── voice-interaction-loop.md
│   ├── design-guidelines.md
│   └── feature-list.md
│
└── docker-compose.yml      # PostgreSQL (pgvector) + Redis
```

## 快速开始

### 前置条件

- Go 1.22+
- Flutter 3.x (Dart 3.8+)
- Docker & Docker Compose
- 腾讯云 SMS/ASR 密钥（或使用 mock 模式）
- OpenRouter API Key（Claude 大模型）

### 1. 启动基础设施

```bash
docker compose up -d
```

PostgreSQL (pgvector) 监听 `5433`，Redis 监听 `6379`。

### 2. 配置并启动服务端

```bash
cd server
cp .env.example .env   # 填入你的 API Key 等配置
go run ./cmd/server
```

服务端默认监听 `:3000`。

<details>
<summary>环境变量一览</summary>

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PORT` | `3000` | 服务端口 |
| `DATABASE_URL` | `postgres://...localhost:5432/command_center` | PostgreSQL 连接串 |
| `REDIS_URL` | `redis://localhost:6379` | Redis 地址 |
| `JWT_SECRET` | `dev-secret-change-me` | JWT 签名密钥 |
| `OPENROUTER_API_KEY` | — | OpenRouter API Key (Claude) |
| `OPENAI_API_KEY` | — | OpenAI API Key (Whisper) |
| `WHISPER_API_URL` | `https://api.openai.com/v1/audio/transcriptions` | Whisper 端点 |
| `SMS_PROVIDER` | `mock` | `mock` 或 `tencent` |
| `ASR_PROVIDER` | `mock` | `mock` 或 `tencent` |
| `TENCENT_SECRET_ID` | — | 腾讯云 SecretId |
| `TENCENT_SECRET_KEY` | — | 腾讯云 SecretKey |
| `TENCENT_SMS_SDK_APP_ID` | — | 腾讯云 SMS App ID |
| `TENCENT_SMS_SIGN_NAME` | — | 腾讯云 SMS 签名 |
| `TENCENT_SMS_TEMPLATE_ID` | — | 腾讯云 SMS 模板 ID |
| `ACCOUNT_ENCRYPT_KEY` | `dev-encrypt-key-change-me-32chr` | 账号信息加密密钥 (32字符) |
| `UPLOAD_DIR` | `./uploads` | 音频/图片上传目录 |

</details>

### 3. 启动 Flutter 客户端

```bash
cd app
flutter pub get
flutter run
```

## API 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/auth/sms-code` | 发送验证码 |
| `POST` | `/api/auth/login` | 验证码登录 |
| `GET` | `/ws` | WebSocket 连接（实时推送） |
| `POST` | `/api/commands` | 创建指令（语音/文字/图片） |
| `POST` | `/api/commands/{id}/follow-up` | 追问/补充 |
| `GET` | `/api/tasks` | 任务列表 |
| `GET` | `/api/tasks/{id}` | 任务详情 |
| `POST` | `/api/tasks/{id}/confirm` | 确认高风险操作 |
| `POST` | `/api/tasks/{id}/cancel` | 取消任务 |
| `POST` | `/api/tasks/{id}/retry` | 重试失败任务 |
| `CRUD` | `/api/sessions` | 会话管理 |
| `CRUD` | `/api/accounts` | 第三方账号管理 |
| `GET/PUT` | `/api/profile` | 用户资料 |
| `GET` | `/api/rules` | 管理规则列表 |
| `DELETE` | `/api/rules/{id}` | 删除规则 |

## 技术栈

| 层级 | 选型 |
|------|------|
| 客户端 | Flutter 3.x · Dart · SQLite (local-first) · WebSocket |
| 服务端 | Go · net/http · pgx · gorilla/websocket |
| 大模型 | Claude (via OpenRouter) · Whisper (STT) · 腾讯云 ASR |
| 数据库 | PostgreSQL 16 (pgvector) · Redis 7 |
| 部署 | Docker · Docker Compose |

## 文档

- [产品需求文档 (PRD)](docs/prd.md)
- [技术架构](docs/technical-architecture.md)
- [语音交互闭环](docs/voice-interaction-loop.md)
- [设计规范](docs/design-guidelines.md)
- [功能清单](docs/feature-list.md)
- [语音模块 README](src/voice/README.md)

## License

Private — All rights reserved.
