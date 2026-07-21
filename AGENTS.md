# 项目协作说明

## 开始前

- 阅读 [文档索引](docs/README.md) 并确认改动涉及的所有者文档。
- 代码、验证、发布和镜像约定以 [开发规范](docs/development-standards.md) 为准。
- 不使用 `.trae`；项目规则统一维护在 `AGENTS.md` 与 `docs/` 中。

## 项目边界

- Web：`apps/web`，Vue 3 + Vite。
- API：`apps/api`，FastAPI + SQLAlchemy + MySQL。
- Crawler：`apps/crawler`，Node.js + TypeScript + Playwright。
- 运行时：Docker Compose 编排 MySQL、Redis、迁移、Crawler、API、Worker 与 Web。

## 不可违反的约束

- 不提交密钥、Cookie、账号、个人信息或外部平台敏感响应。
- 不编辑、重编号或删除已经执行的数据库迁移；只新增前向迁移。
- 不绕过外部操作的幂等、租约、不确定状态和人工核对机制。
- Crawler 仅允许内部调用，保持 `X-Internal-Token` 和目标域名白名单限制。
- 改动部署、配置、安全边界、用户可见行为或运维命令时，同步更新对应专题文档。
- 项目卸载必须限定在 Compose 项目标签和明确的项目镜像名内，不执行 Docker 全局清理。

## 交付前

- 执行与改动范围匹配的验证，至少运行 `scripts/verify-local.ps1` 或开发规范中的等价命令。
- 在变更说明中记录已执行验证以及未执行项和原因。
- 提交使用简化的 Conventional Commits：英文类型后直接接中文描述，不使用作用域括号。
- 用户可见功能或修复进入 `main` 前，按开发规范更新 `CHANGELOG.md`。
