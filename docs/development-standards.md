# 开发规范

本文定义代码变更、验证、发布、变更日志和 Docker 镜像发布的项目规则，并取代
原有编辑器专属规则。

## 范围与优先级

1. 安全、数据完整性、平台条款和明确的生产控制优先于开发便利。
2. 仓库既有契约优先于新建的局部约定。
3. 一项行为变更应在同一个可审查变更中包含代码、针对性验证和所有者文档更新。
4. 不得在源码、测试、截图、夹具、URL、提交记录或日志中写入账号、Cookie、密钥、
   个人信息或平台响应原文。

## 代码约定

### Python API

- 数据库访问使用 SQLAlchemy 2.0 的异步模式。
- HTTP 层代码放在 `apps/api/app/api/v1/routes/`；可复用业务逻辑放在
  `apps/api/app/services/`；通用基础设施放在 `apps/api/app/core/`。
- 保持统一响应信封、请求上下文、审计和路由唯一性契约，禁止注册重复的
  HTTP 方法和路径。
- 对外部平台和通知操作在持久化结果确认前一律视为不确定状态；保留幂等键、租约和
  人工核对路径。
- 数据库结构变化必须新增编号递增的前向迁移；不得编辑、重编号或删除已执行迁移。
  发布与恢复要求以迁移手册为准。

### Vue Web

- 使用 Vue 3 Composition API 与 `<script setup>`。
- 通过 `apps/web/src/utils/request.js` 和 `apps/web/src/api/` 中的模块请求 API，
  页面组件中不得新建临时请求客户端。
- 路由页面放在 `apps/web/src/pages/`，复用 UI 放在 `apps/web/src/components/`，跨页面
  状态或行为放在 `apps/web/src/composables/` 或 `apps/web/src/utils/`。
- 生产代码不得保留 `console.log`；临时诊断须由 `import.meta.env.DEV` 保护并在合并前删除。
- 不可信 URL 和上传媒体必须复用现有安全工具，不得另建绕过既有校验的白名单。

### Crawler 与外部集成

- Crawler 仅在应用内部网络暴露；每个 `/api/*` Crawler 路由都必须校验
  `X-Internal-Token`。
- 浏览器导航仅允许配置的 HTTPS 域名白名单；扩展白名单必须经过安全评审。
- 浏览器并发、输入大小、超时和重试必须有上限，不得为规避短暂的平台故障而放宽限制。

## 验证

提交评审前执行与改动范围匹配的检查。

```powershell
# Windows 本地校验
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-local.ps1

# 工具已安装时的等价检查
npm --prefix apps/web run lint
npm --prefix apps/web run build
python -m compileall -q apps/api/app
npm --prefix apps/crawler run build
```

- 为受影响行为新增或更新针对性自动化测试。涉及外部副作用时，使用可控替身验证幂等、
  超时或不确定结果及恢复路径。
- 当验证依赖浏览器、平台账号、密钥或部署环境时，在 Pull Request 中记录手动验证步骤。
- 不得将仅构建通过表述为端到端、生产、安全或恢复验证证据。
- 处理生产报错时，必须先以实际异常堆栈、数据库错误码、请求响应或可控复现之一确认
  根因。未取得证据时只能明确标记为假设并说明取证步骤；不得仅据此提交代码、数据库
  迁移或配置修复，也不得将假设表述为已确认结论。

## 内部提交规范

- 使用简化的 Conventional Commits：`<type>: <description>`，不使用作用域括号。
- `type` 使用英文关键字，`description` 使用简洁中文；不要使用英文描述替代项目
  提交说明。例如：`docs: 整理项目文档与协作规范`。
- 类型限定为 `feat`、`fix`、`docs`、`style`、`refactor`、`perf`、`test` 和 `chore`。
- 除非明确需要发布或维护分支，从 `main` 创建 `feat/<name>` 或 `fix/<name>` 分支。
- 提交说明必须描述行为变化、已执行验证、运维或安全影响以及文档更新。
- 安全漏洞遵循 `SECURITY.md` 的流程处理，不得通过公开 Issue 或 Pull Request 报告。

## 变更日志与发布

- 向 `main` 推送用户可见的新功能或修复前，必须更新 `CHANGELOG.md`，不得只提交代码。
- 未发布内容放在 `## [Unreleased]`；发布时改为 `## [vX.Y.Z] - YYYY-MM-DD`，并新建空的
  `Unreleased` 段落。
- 使用 `### 新增`、`### 变更` 和 `### 修复` 小节；没有内容的分类可以省略。
- 遵循语义化版本：不兼容变更增加主版本，兼容新功能增加次版本，兼容修复增加修订号。
- 用一句话描述用户可见结果；纯格式化、重构和仅测试变更通常无需记录到变更日志。
- 发布 Tag 必须与变更日志版本一致：`git tag vX.Y.Z`。

## Docker 镜像发布

- 推送到 `main` 会触发 `.github/workflows/docker-publish.yml`，自动构建并发布 `api`、
  `web` 和 `crawler` 到 GHCR；标准发布流程不得手工推送替代镜像。
- 镜像发布 `linux/amd64` 与 `linux/arm64` 多架构版本，并带有 `latest` 与 Git 短 SHA 标签。
- 修改 Python 依赖时，必须通过 `pip-compile --generate-hashes` 从
  `apps/api/requirements.in` 生成 `apps/api/requirements.txt`，并保留两个目标架构可用的哈希。
- 新增容器化服务时，使用多架构基础镜像；在工作流矩阵中声明服务；在
  `docker-compose.yml` 中同时声明对应的 `image` 与 `build`。
- 修改镜像命名空间时，同一变更中更新工作流 `IMAGE_NAMESPACE`、Compose 镜像默认值和
  `.env.example` 的镜像变量。
- 生产初始化、启动、检查更新、更新、停止和卸载统一使用 `deploy.sh` 子命令；镜像构建由 `up` 自动完成。
- `uninstall` 只能删除 Compose 标签精确匹配本项目的资源和明确列出的项目镜像，不得调用
  `docker system prune` 或删除共享基础镜像；必须交互确认后才能删除数据与生成配置。

## 文档维护

- 通过 [文档索引](README.md) 查找每个主题的所有者文档。
- 命令、配置、安全控制、数据处理、部署行为或用户可见能力变化时，更新对应的
  所有者文档。
- `README.md` 与本文只保留入口和规则，不复制长篇操作流程。
