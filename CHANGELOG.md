# 更新日志

本项目所有显著变更均记录于此文件。格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，遵循语义化版本 [SemVer](https://semver.org/lang/zh-CN/)。

- **主版本号**：不兼容的破坏性变更
- **次版本号**：向下兼容的新功能
- **修订号**：向下兼容的问题修复

## [Unreleased]

### 变更

- **项目命名统一**：仓库、Compose 资源、数据库、服务标识、本地镜像和 GHCR 镜像统一使用 `xianyu-pilot` 名称。
- **MySQL 账号模型精简**：删除自定义双账号初始化脚本和迁移专用凭据，改由官方镜像创建单一非 root app 用户，供 API、Worker 和迁移共用；root 仅用于初始化和恢复。
- **Linux 生产入口收敛**：删除 Windows 生产启动、初始化和验证入口，生产部署统一使用 Shell 脚本；本地开发入口留待后续阶段单独整理。
- **容器端口统一**：生产 Web、API、Crawler 使用连续的 `12400`、`12401`、`12402`，Web 宿主机与容器端口保持一致且默认仅绑定回环地址。
- **首次密码加固**：移除 `admin123` 默认密码，首次初始化改为生成并仅显示一次随机管理员密码，已有密码哈希时不再输出误导性密码。

### 新增
- **项目级一键卸载**：新增 `./deploy.sh uninstall`，二次确认后删除本项目运行资源、数据、项目镜像和生成配置，同时保留源码与共享基础镜像。
- **统一生产部署入口**：`deploy.sh` 提供 `init`、`up`、`status`、`logs`、`check-update`、`update`、`stop` 和 `uninstall` 子命令，`up` 自动构建 Git SHA 镜像；`update` 始终更新到最新正式版本且不自动备份或回滚。
- **首次初始化脚本**：新增 `scripts/init.sh`，首次启动自动生成 6 组随机 secrets（MySQL root/app、Redis、JWT、Cookie、Token，均 Base64URL 编码 ≥32 字符）、4 个空的可选 secrets、bcrypt cost 12 admin 密码 hash 和 `.env` 文件；优先用主机 Python，缺失时自动退到 Docker 临时容器生成
- **小刀订单免拼发货**：小刀（砍价）订单自动调用闲鱼免拼发货接口（mtop.idle.groupon.activity.seller.freeshipping）完成发货，而非普通确认发货接口；订单同步时通过 btnList 的 SKIP_PIN 自动检测小刀订单并标记 is_bargain（只置 True 不回退）；自动发货网关根据订单小刀状态智能路由免拼/确认发货接口
- **发布商品页面增强**：运费设置支持包邮/一口价/无需邮寄三模式互斥切换；图片 URL 增加 resolveTrustedMediaUrl 白名单防护（防 XSS）；图片上传增加 imageUploadValidationMessage 预校验（大小≤5MB、MIME 类型、扩展名）；账号选择增加 pickPreferredAccount 智能选择（优先可用账号）
- **在线消息页面客户订单板块**：会话侧边栏新增客户订单卡片（封面、状态徽章、金额、订单详情入口）；新增 getCustomerOrders API；后端 /orders 接口支持 buyerId 过滤
- **发布商品基础设施**：新增 requestLifecycle.js（createRequestGate 请求竞态保护）、imageUploadPolicy.js（图片上传预校验）、publishAddress.js（地址标准化工具）、PublishAddressCascader.vue（三级地址级联选择器）、safeMediaUrl.js（可信媒体 URL 校验）
- **发货记录页面数据完整性**：后端 SQL 补齐 purchase_time/goods_cover_pic/seller_name/seller_display_name/goods_id 字段；JOIN xianyu_account 表获取卖家信息；前端新增商品缩略图列（含 onGoodsThumbError 容错）、卖家列、购买时间列；详情面板新增外部订单号/商品ID/卖家/购买时间字段
- **一键检查 GitHub 更新**：在"关于我们"页新增"版本更新检查"卡片，统一生成 `./deploy.sh update` 命令，并保留 Release 下载入口和 GitHub API 失败兜底。
- **首次登录引导清单**：`DashboardPage` 顶部接入 `OnboardingChecklist`，通过 `localStorage` 持久化完成状态，支持"不再提示"按钮；自动检查 `/system/runtime-status` 同步模型配置完成情况
- **README 快速上手章节**：新增"3 分钟快速上手"章节，包含前置要求、3 步启动、常见问题表格，新手无需阅读生产部署详细文档即可上手
- **错误文案带下一步建议**：`friendlyError.js` 扩展数据库/Redis/WebSocket/Token 失效/同步失败等错误的文案，直接告诉用户"下一步该怎么做"

### 优化
- **侧栏导航层级**：一级菜单调整为可展开的业务分类，页面入口统一放入二级菜单；按账号接入、商品运营、客户订单、发货履约、自动化运营和系统支持重组入口，并将通知设置纳入设置页导航。
- **商品管理页面健壮性**：pollSyncProgress 增加连续失败熔断（3次即抛错）与严格响应校验（status 白名单/pct 范围[0,100]/对象类型校验）；init 改为分步容错加载（账号失败不阻塞后续）；loadGoodsStats 严格校验排除 null/undefined/空字符串；syncAllAccounts 进度防倒退（删除每账号 progress=0 重置）；batchDeleteProducts 增加 warnings 分类（remote_confirmed/warn 类型记为需人工核对而非失败）
- **订单管理页面严格校验**：syncCurrentOrder 增加 data.ok 布尔校验与成功/失败分支；selectOrder 增加 id 匹配校验与 ordersAvailable 前置检查，去除 row 回退；新增 detailLoadError 独立错误状态；syncAccountOrders 增加响应格式校验；openManualDelivery 利用 selectOrder 返回值
- **发货记录页面严格验证**：load() 改用 recordsOfOrThrow 替代 recordsOf（异常时抛错而非静默降级为空列表）
- **API 数据工具增强**：apiData.js 新增 recordsOfOrThrow（严格版，异常抛错）；totalOf 增加 Number.isSafeInteger 与负数校验
- **账号鉴权工具增强**：accountAuth.js 新增 pickPreferredAccount（智能账号选择）、accountWsConnectionState（WS 三态）、resolveAccountAuthDisplayState（Cookie+WS 综合状态）、shouldAttemptAccountWebSocketStart

### 修复
- **Compose secret 告警**：移除文件型 secret 挂载中被 Compose 忽略的 `uid`、`gid` 和 `mode` 属性，避免部署时产生重复兼容性警告。
- **顶部工具栏不可点击**：提高右上角通知、帮助、全屏和用户菜单的层级，避免透明页头遮挡其点击事件。
- **卡密仓库入口**：将已有的卡密分组、库存、导入和使用记录页面注册到路由，并在“自动化”菜单中提供入口。
- **全局请求状态残留**：前端现在使用发起请求时的请求 ID 结束加载状态，避免 Nginx 重写上游请求 ID 后，“正在同步数据...”提示持续显示。
- **生产密钥权限校验修复**：预检现在允许 Compose 所需的 `secrets/` 目录 `0700`、文件 `0644` 组合，同时继续拒绝公开目录或可被其他用户写入的密钥文件。
- **生产预检警告修复**：修正未配置 `PUBLIC_BASE_URL` 时调用错误方法导致 `./deploy.sh up` 中断的问题。
- **仓库与镜像地址修正**：克隆地址、版本检查、Release 链接和 GHCR 镜像命名空间统一指向 `hongliyuu/xianyu-pilot`。
- **docker-compose secrets 机制修复**：原 `secrets:` 顶层使用 `environment: ADMIN_PASSWORD_HASH` 模式期望主机环境变量为明文，但 `.env.example` 仅配置了 `_FILE` 路径变量，导致 `docker compose up` 时 secret 内容为空触发 fail-closed 启动失败；现统一改为 `file: ./secrets/<name>` 模式，与 `.env.example` 的 `_FILE` 路径完全对齐
- **生产部署默认值修复**：`.env.example` 中 `AUDIT_MUTATION_INTENT_REQUIRED` 改为 `true`（生产预检强制要求），`WEB_BIND_ADDRESS` 改为 `0.0.0.0`（便于局域网访问，原 `127.0.0.1` 导致 VPS 部署后浏览器无法访问）
- **订单同步结果判断 BUG**：syncCurrentOrder 此前忽略 data.ok 字段，同步失败时仍显示绿色成功提示；现改为基于 data.ok 分支显示成功或失败
- **订单详情回退到行数据**：selectOrder 此前在详情加载失败时回退到 row 概要数据当详情展示；现改为严格校验 id 匹配，失败时不回退
- **仪表盘功能特性板块溢出**：在 1501-1680px 中宽屏下，「功能特性」与「快速开始」卡片降为 3 列布局，解决 4 列时单卡过窄导致长描述与「点击进入 XXX」副文本大量换行、超出容器的问题

## [v1.1.0] - 2026-07-15

### 新增
- **Docker 镜像自动构建与发布**：每次推送到 `main` 分支时，GitHub Actions 自动构建 `api`/`web`/`crawler` 镜像并推送至 GHCR（`ghcr.io/hongliyuu/xianyu-pilot-{api,web,crawler}`），支持 `latest` 与 git 短 SHA 双标签
- **一键拉取预构建镜像运行**：`docker compose pull && docker compose up -d`，无需本地源码构建
- **镜像源可覆盖**：通过 `.env` 的 `API_IMAGE`/`WEB_IMAGE`/`CRAWLER_IMAGE` 切换命名空间或镜像源
- **更新日志机制**：新增 `CHANGELOG.md`，并落地为项目规则，每次上传追加版本记录

### 变更
- `docker-compose.yml` 中 `api`/`migrate`/`crawler`/`web` 服务的 `image` 默认值由本地标签改为 GHCR 路径，同时保留 `build` 字段以便 `--build` 切回本地构建

### 修复
- **商品同步接口异常处理**：`/items/sync-progress/{sync_id}` 与 `/items/syncing/{account_id}` 两个端点增加 try/except 兜底，避免数据库查询或内存进度读取异常时直接返回 500，改为记录日志并返回统一错误响应

## [v1.0.0] - 2026-07-14

闲鱼助手开源版首个正式发布版本。

### 功能亮点
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

### 技术架构
- 后端 API：Python 3.11 + FastAPI + SQLAlchemy 2.0
- 前端 Web：Vue 3 + Vite
- 爬虫服务：Node.js 22 + TypeScript + Playwright
- 数据库：MySQL 8.0
- 缓存：Redis 7
- 反向代理：Nginx
- 部署方式：Docker Compose

### 安全特性
- 全套生产秘密通过文件注入（`secrets/` 目录 `0700`，文件 `0644`）
- MySQL root 与数据库级 app 账号分离
- 容器 `read_only` + `cap_drop: ALL` + `no-new-privileges` 加固
- JWT 认证、Cookie 加密、CORS 白名单、登录限流
- 审计日志与保留期管理
