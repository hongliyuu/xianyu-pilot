<div align="center">

# Xianyu Pilot

**一套面向闲鱼卖家的自动化运营管理后台 — 账号、商品、订单、消息、自动发货、卡密、AI 自动回复，一站搞定。**

![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.110-009688?logo=fastapi&logoColor=white)
![Vue](https://img.shields.io/badge/Vue-3-42b883?logo=vuedotjs&logoColor=white)
![Vite](https://img.shields.io/badge/Vite-5-646CFF?logo=vite&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white)
![Redis](https://img.shields.io/badge/Redis-7-DC382D?logo=redis&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![Node](https://img.shields.io/badge/Node.js-22-339933?logo=nodedotjs&logoColor=white)

</div>

---

一套面向闲鱼卖家的**单用户自动化运营后台**，覆盖账号、商品、订单、消息、自动发货、卡密、AI 自动回复等核心场景。开箱即用，支持 Docker Compose 一键部署，也支持本地裸机开发。

遇到行为差异时，以当前仓库的代码、测试和文档为准。

## 📸 项目截图

| 控制台仪表盘 | 账号管理 |
| :---: | :---: |
| ![仪表盘](screenshots/dashboard.png) | ![账号管理](screenshots/accounts.png) |

| 商品管理 | 订单管理 |
| :---: | :---: |
| ![商品管理](screenshots/products.png) | ![订单管理](screenshots/orders.png) |

| 在线消息 | 自动发货 |
| :---: | :---: |
| ![在线消息](screenshots/messages.png) | ![自动发货](screenshots/auto-delivery.png) |

| AI 自动回复 | 商品发布 |
| :---: | :---: |
| ![AI 自动回复](screenshots/auto-reply.png) | ![商品发布](screenshots/product-publish.png) |

| 数据看板 | 系统配置 |
| :---: | :---: |
| ![数据看板](screenshots/data-panel.png) | ![系统配置](screenshots/settings.png) |

| 移动端 - 仪表盘 | 移动端 - 消息 |
| :---: | :---: |
| ![移动端仪表盘](screenshots/mobile-dashboard.png) | ![移动端消息](screenshots/mobile-messages.png) |

## ✨ 功能亮点

- 🧑‍💼 **闲鱼账号管理** — 多账号接入、二维码登录、状态监控
- 📦 **商品管理与发布** — 上下架、编辑、批量操作、分类
- 🧾 **订单管理** — 同步、跟踪、状态流转
- 💬 **在线消息** — 实时会话、WebSocket 长连接、分页回溯
- 🚚 **自动发货** — 卡密自动交付、实时与手动双通道
- 🎫 **卡密仓库** — 库存管理、去重、交付记录
- 🤖 **自动回复** — AI 驱动、知识库增强、人设与规则可配
- ⏰ **定时任务** — 调度执行、心跳与租约保护
- 📝 **操作日志** — 审计留痕、保留期管理
- 🔔 **通知渠道** — 持久化防重复测试发送，未知结果只能人工确认关闭
- 📚 **RAG 知识库** — 向量检索增强回复
- ⚙️ **系统配置** — 通用模型、向量模型、RAG、高德地图、商业版桥接状态
- 🧩 **Crawler 滑块求解** — 由 API 同会话维护的二维码登录
- 🏠 **首页运营** — 轮播、公告、文字广告、广告申请、关于我们
- 🔗 **反馈建议** — 向我们反馈功能建议

## 🖼️ 商业版预览
| 商业版 - 截图 1 | 商业版 - 截图 2 |
| :---: | :---: |
| ![商业版1](screenshots/commercial-1.png) | ![商业版2](screenshots/commercial-2.png) |

## 🏆 商业版服务

如果你需要更稳定、更强大的能力，或希望获得 **7×24 小时** 的技术支持与托管服务，欢迎了解我们的商业版：

👉 **[访问商业版服务](https://www.xianyupilot.com/#/)** 

商业版在开源版基础上提供更完善的多账号管理、商机发掘、工作流自动化、专属客服与运维保障。开源版与商业版可独立运行，互不冲突。

## 🚀 3 分钟快速上手

> 适合第一次使用的用户。一键脚本会自动生成所有 secrets、bcrypt 密码 hash、`.env` 配置，无需手动创建任何密码文件。
>
> 生产准入、本地开发和迁移维护等专题资料见 [文档索引](docs/README.md)。

### 前置要求
- Docker 24+ 与 Docker Compose v2
- Linux 服务器（推荐 4 核 8GB 内存）

### 步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/hongliyuu/xianyu-pilot.git
   cd xianyu-pilot
   ```

2. **初始化、构建并启动**
   ```bash
   chmod +x deploy.sh
   ./deploy.sh init
   ./deploy.sh up
   ```

   `init` 生成配置、密钥和随机管理员密码；`up` 使用当前 Git SHA 构建镜像，执行
   生产预检、数据库迁移、启动服务并等待健康检查。

3. **访问服务**

   Web 默认监听 http://127.0.0.1:12400

   - 默认账号：`admin`
   - 首次随机密码只在初始化终端显示一次

### 自定义 admin 密码

```bash
# 在启动前设置环境变量
ADMIN_PASSWORD="your-strong-password" ./deploy.sh init
```

### 常见问题

| 问题 | 解决方法 |
|---|---|
| 端口 12400 被占用 | 修改 `.env` 中的 `WEB_PORT` 后执行 `./deploy.sh up` |
| 构建失败 | 检查 Docker、网络和磁盘空间，然后重新执行 `./deploy.sh up` |
| 忘记 admin 密码 | 删除 `./secrets/admin-password-hash`，设置 `ADMIN_PASSWORD` 后执行 `./deploy.sh init` |
| 想更新到最新版 | 先执行 `./deploy.sh check-update`，再执行 `./deploy.sh update` |
| 其他机器无法直连 | 默认仅绑定 `127.0.0.1:12400`；外部入口由部署环境自行配置 |

---

## 🧱 技术架构

| 层级 | 技术 |
|------|------|
| 后端 API | Python 3.11 + FastAPI + SQLAlchemy 2.0 |
| 前端 Web | Vue 3 + Vite |
| 爬虫服务 | Node.js 22 + TypeScript + Playwright |
| 数据库 | MySQL 8.0 |
| 缓存 | Redis 7 |
| 反向代理 | Nginx |
| 部署方式 | Docker Compose |

## 📁 目录结构

```text
xianyu-pilot/
├── apps/
│   ├── api/        # FastAPI 后端、SQL migration、上传目录挂载点
│   ├── crawler/    # Playwright 子服务，仅负责滑块求解
│   └── web/        # 合并后的 Vue 前端
├── docs/           # 开发、生产准入与迁移文档
├── scripts/        # 生产运维与本地开发脚本
├── screenshots/    # README 截图
├── docker-compose.yml
├── deploy.sh
└── .env.example
```

## 🚀 快速开始（生产候选部署）

### 前置要求

- 受支持的 Linux 与 Docker Engine
- Docker Compose v2（已包含在 Docker Desktop 和 `docker-compose-plugin` 中）
- 推荐同机 TLS 反向代理（如需对公网服务）

### 部署入口

生产操作全部通过 `deploy.sh`，不要直接拼接 Git 或 Compose 更新命令：

```bash
./deploy.sh init
./deploy.sh up
./deploy.sh status
./deploy.sh logs api
./deploy.sh check-update
./deploy.sh update
./deploy.sh stop
./deploy.sh uninstall
```

应用镜像使用当前 Git 短 SHA 作为标签，不使用 `latest` 记录部署状态。当前版本和候选版本
保存在忽略提交的 `.deploy/` 目录。更新不会自动备份或回滚。

> Compose 会先运行一次性 `migrate` 服务，再允许 API 和 Worker 启动；新库与旧库都走同一个带历史记录和 MySQL 单实例锁的版本化 runner。维护窗口、备份、状态检查和回滚兼容流程见 [`apps/api/migrations/README.md`](apps/api/migrations/README.md)。

### 运行边界

Web 默认绑定宿主机 `127.0.0.1:12400`。API、Crawler、MySQL 和 Redis 不发布宿主机端口，外部入口由部署环境自行管理。

> API 错误同时使用真实 HTTP 状态码和顶层 `code/msg/data` 信封：参数错误、冲突、资源不存在、依赖不可用和内部错误不会再以 HTTP 200 伪装成功。调用方应以 HTTP 状态为主、信封错误码为业务细节；已退役兼容面统一返回 HTTP 410 和迁移指引。

## 🖥️ 本地开发

本地开发与生产部署是两条独立路径。生产 `docker-compose.yml` 会强制要求全部生产秘密，不应再被当作"只启动 MySQL/Redis"的无密码开发捷径。完整步骤、端口和本地裸机启动方式见 [`docs/local-dev-runbook.md`](docs/local-dev-runbook.md)。

Crawler 的所有 `/api/*` 路由都应使用 `X-Internal-Token`；生产仅允许容器内 API 访问。健康检查是 `/health`，就绪检查是 `/ready`。


### 代码中还支持的补充变量

以下变量在 `apps/api/app/core/config.py` 中也已支持；其中商业版桥接相关变量和 `INTERNAL_API_TOKEN_FILE` 已经写进 `.env.example`，这里只列仍需按需手动追加的部分：

- `APP_ENV`
- `AI_PROVIDER_ENABLED`
- `AI_PROVIDER_BASE_URL`
- `AI_PROVIDER_API_KEY`
- `AI_PROVIDER_MODEL`
- `AI_PROVIDER_TIMEOUT_SECONDS`
- `AMAP_API_KEY`

## 🌐 生产网络边界

| 服务 | 容器端口 | 宿主发布 |
|------|------|------|
| Web | `12400` | 默认 `127.0.0.1:12400` |
| API | `12401` | 不发布，仅 Web/内部网络 |
| Crawler | `12402` | 不发布，仅 API/内部网络 |
| MySQL | `3306` | 不发布，仅内部网络 |
| Redis | `6379` | 不发布，仅内部网络 |

## 🛠️ 常用命令

常用运维命令：

```bash
# 查看服务和版本
./deploy.sh status

# 查看 API 日志
./deploy.sh logs api

# 检查并执行更新
./deploy.sh check-update
./deploy.sh update

# 停止服务，不删除数据卷和镜像
./deploy.sh stop

# 完全卸载本项目（需要输入 xianyu-pilot 确认）
./deploy.sh uninstall
```

`logs` 服务名仅允许 `mysql`、`redis`、`migrate`、`api`、`worker`、`crawler`、`web`。
`uninstall` 会永久删除本项目容器、网络、数据卷、项目镜像以及生成的 `.env`、`secrets/`、
`.deploy/`；源码仓库、MySQL/Redis 基础镜像和其他 Docker 项目不受影响。


## 📚 参考文档

完整的文档分层、维护边界和阅读路径见 [`docs/README.md`](docs/README.md)。

| 文档 | 说明 |
|------|------|
| [`docs/README.md`](docs/README.md) | 文档索引与维护规范 |
| [`docs/development-standards.md`](docs/development-standards.md) | 研发、验证、发布与镜像规范 |
| [`docs/local-dev-runbook.md`](docs/local-dev-runbook.md) | 本地开发运行手册 |
| [`docs/production-readiness.md`](docs/production-readiness.md) | 生产发布准入与已知约束 |
| [`apps/api/migrations/README.md`](apps/api/migrations/README.md) | 数据库迁移说明 |
| [`SECURITY.md`](SECURITY.md) | 安全策略 |
## 🧸 特别鸣谢

本项目在开发过程中参考了以下开源项目，特此致谢：

- [xianyuapis](https://github.com/IAMLZY2018/xianyuapis) — 闲鱼相关 API 的实现思路与协议参考。

## 📄 许可证：Apache-2.0 许可证

本项目采用 [Apache License 2.0](LICENSE) 授权。任何人可在遵守该许可证条款的前提下自由使用、修改和分发本仓库代码。

---

## 💖 赞助

如果这个项目帮助到了你，或者你通过它赚到了钱，并且你愿意的话，希望你能赞助支持我的持续开发与维护工作。你的支持是我继续迭代、修复问题、添加新功能的动力。

<div align="center">

![赞助码](screenshots/qr.png)

</div>

<div align="center">

<sub>Made with care for the 闲鱼 seller community.</sub>

</div>
