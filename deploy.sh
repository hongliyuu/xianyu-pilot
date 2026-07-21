#!/usr/bin/env sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$PROJECT_DIR"

ENV_FILE="$PROJECT_DIR/.env"
STATE_DIR="$PROJECT_DIR/.deploy"
CURRENT_FILE="$STATE_DIR/current"
CANDIDATE_FILE="$STATE_DIR/candidate"
PROJECT_NAME="xianyu-pilot"
DEPLOY_REMOTE=${DEPLOY_REMOTE:-origin}
DEPLOY_BRANCH=${DEPLOY_BRANCH:-main}
WAIT_TIMEOUT_SECONDS=${WAIT_TIMEOUT_SECONDS:-300}
ALLOWED_SERVICES="mysql redis migrate api worker crawler web"

info() { printf '%s\n' "[信息] $*"; }
ok() { printf '%s\n' "[完成] $*"; }
warn() { printf '%s\n' "[警告] $*" >&2; }
die() { printf '%s\n' "[错误] $*" >&2; exit 1; }

show_help() {
  cat <<'EOF'
用法：./deploy.sh <命令> [参数]

  init                    初始化 .env 和密钥
  up                      构建、预检并启动全部服务
  status                  查看服务与部署版本
  logs [服务名]           查看最近 200 行日志
  check-update            检查远端正式版本
  update                  更新到最新正式版本
  stop                    停止服务，不删除数据卷和镜像
  uninstall               卸载本项目并删除数据、镜像和生成配置

服务名：mysql redis migrate api worker crawler web
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "未找到命令：$1"
}

require_linux() {
  [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "生产部署脚本仅支持 Linux"
}

require_docker() {
  require_command docker
  docker compose version >/dev/null 2>&1 || die "需要 Docker Compose v2"
  docker info >/dev/null 2>&1 || die "Docker 服务不可用；请先安装并启动 Docker，并配置当前用户权限"
}

require_git() {
  require_command git
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "当前目录不是 Git 工作区"
}

require_initialized() {
  [ -f "$ENV_FILE" ] || die "尚未初始化，请先执行 ./deploy.sh init"
  for name in admin-password-hash mysql-root-password mysql-app-password \
    redis-password jwt-secret cookie-crypto-secret internal-api-token; do
    [ -s "$PROJECT_DIR/secrets/$name" ] || die "缺少密钥 secrets/$name，请重新执行 ./deploy.sh init"
  done
}

ensure_state_dir() {
  mkdir -p "$STATE_DIR"
  chmod 700 "$STATE_DIR" 2>/dev/null || true
}

compose() {
  docker compose --env-file "$ENV_FILE" --project-name "$PROJECT_NAME" "$@"
}

is_allowed_service() {
  requested=$1
  for service in $ALLOWED_SERVICES; do
    [ "$requested" = "$service" ] && return 0
  done
  return 1
}

require_clean_tree() {
  [ -z "$(git status --porcelain --untracked-files=no)" ] || \
    die "Git 工作区存在未提交修改，拒绝构建或切换生产版本"
}

current_git_version() {
  git rev-parse --short=12 HEAD
}

validate_version_id() {
  case "$1" in
    ''|*[!A-Za-z0-9_.-]*) die "无效版本标识：$1" ;;
  esac
}

export_release_images() {
  release=$1
  validate_version_id "$release"
  export API_IMAGE="xianyu-pilot-api:$release"
  export WEB_IMAGE="xianyu-pilot-web:$release"
  export CRAWLER_IMAGE="xianyu-pilot-crawler:$release"
}

read_state() {
  file=$1
  [ -s "$file" ] || return 1
  value=$(sed -n '1p' "$file")
  validate_version_id "$value"
  printf '%s\n' "$value"
}

write_state() {
  file=$1
  value=$2
  validate_version_id "$value"
  ensure_state_dir
  temporary="$file.tmp.$$"
  umask 077
  printf '%s\n' "$value" > "$temporary"
  mv "$temporary" "$file"
}

load_runtime_images() {
  if release=$(read_state "$CURRENT_FILE" 2>/dev/null); then
    export_release_images "$release"
  elif release=$(read_state "$CANDIDATE_FILE" 2>/dev/null); then
    export_release_images "$release"
  fi
}

run_preflight() {
  compose config --quiet
  docker image inspect "$API_IMAGE" >/dev/null 2>&1 || die "API 镜像不存在，自动构建未完成"
  docker run --rm --read-only \
    --user 0:0 \
    -v "$PROJECT_DIR:/workspace:ro" \
    -w /workspace \
    "$API_IMAGE" \
    python scripts/production_preflight.py --env-file .env
}

wait_ready() {
  port=$(sed -n 's/^WEB_PORT=//p' "$ENV_FILE" | tail -n 1)
  port=${port:-12400}
  url="http://127.0.0.1:$port/readyz"
  attempts=$((WAIT_TIMEOUT_SECONDS / 3))
  [ "$attempts" -gt 0 ] || attempts=1

  count=0
  while [ "$count" -lt "$attempts" ]; do
    if command -v curl >/dev/null 2>&1; then
      curl -fsS --max-time 3 "$url" >/dev/null 2>&1 && return 0
    elif command -v wget >/dev/null 2>&1; then
      wget -qO- --timeout=3 "$url" >/dev/null 2>&1 && return 0
    else
      compose ps --status running --services | grep -qx web && return 0
    fi
    count=$((count + 1))
    sleep 3
  done
  return 1
}

record_successful_release() {
  release=$1
  write_state "$CURRENT_FILE" "$release"
  rm -f "$CANDIDATE_FILE"
}

command_init() {
  require_linux
  sh "$PROJECT_DIR/scripts/init.sh"
  chmod 600 "$ENV_FILE" 2>/dev/null || true
  ensure_state_dir
  ok "初始化完成；下一步执行 ./deploy.sh up"
}

ensure_release_images() {
  release=$(current_git_version)
  export_release_images "$release"

  if docker image inspect "$API_IMAGE" "$WEB_IMAGE" "$CRAWLER_IMAGE" >/dev/null 2>&1; then
    write_state "$CANDIDATE_FILE" "$release"
    info "复用已构建镜像 $release"
    return
  fi

  info "构建版本 $release"
  compose build api crawler web
  docker image inspect "$API_IMAGE" >/dev/null 2>&1 || die "API 镜像构建结果不存在"
  docker image inspect "$WEB_IMAGE" >/dev/null 2>&1 || die "Web 镜像构建结果不存在"
  docker image inspect "$CRAWLER_IMAGE" >/dev/null 2>&1 || die "Crawler 镜像构建结果不存在"
  write_state "$CANDIDATE_FILE" "$release"
  ok "镜像构建完成"
}

command_up() {
  require_linux
  require_docker
  require_git
  require_initialized
  require_clean_tree
  ensure_release_images
  release=$(read_state "$CANDIDATE_FILE" 2>/dev/null || read_state "$CURRENT_FILE" 2>/dev/null || true)
  [ -n "$release" ] || die "没有可部署版本"
  [ "$(current_git_version)" = "$release" ] || die "当前 Git 版本与候选镜像不一致，请重新执行 ./deploy.sh up"
  export_release_images "$release"

  info "执行生产预检"
  run_preflight
  info "启动版本 $release"
  compose up -d --no-build --wait --wait-timeout "$WAIT_TIMEOUT_SECONDS"
  if ! wait_ready; then
    compose ps --all || true
    die "Web 就绪检查超时，请执行 ./deploy.sh logs web"
  fi
  record_successful_release "$release"
  port=$(sed -n 's/^WEB_PORT=//p' "$ENV_FILE" | tail -n 1)
  ok "部署完成：http://127.0.0.1:${port:-12400}"
}

command_status() {
  require_docker
  require_initialized
  load_runtime_images
  current=$(read_state "$CURRENT_FILE" 2>/dev/null || true)
  printf '当前版本：%s\n' "${current:-未记录}"
  compose ps --all
}

command_logs() {
  require_docker
  require_initialized
  load_runtime_images
  service=${1:-}
  [ "$#" -le 1 ] || die "logs 最多接受一个服务名"
  if [ -n "$service" ]; then
    is_allowed_service "$service" || die "不支持的服务名：$service"
    compose logs --tail 200 "$service"
  else
    compose logs --tail 200
  fi
}

latest_target() {
  latest=$(git tag --list 'v[0-9]*' --sort=-v:refname | sed -n '1p')
  if [ -n "$latest" ]; then
    printf '%s\n' "$latest"
  else
    printf '%s/%s\n' "$DEPLOY_REMOTE" "$DEPLOY_BRANCH"
  fi
}

command_check_update() {
  require_git
  info "获取远端版本信息"
  git fetch --tags "$DEPLOY_REMOTE" "$DEPLOY_BRANCH"
  target=$(latest_target)
  target_sha=$(git rev-parse --short=12 "$target^{commit}")
  current_sha=$(current_git_version)
  current_tag=$(git describe --tags --exact-match HEAD 2>/dev/null || true)
  printf '当前版本：%s (%s)\n' "${current_tag:-未标记}" "$current_sha"
  printf '最新版本：%s (%s)\n' "$target" "$target_sha"
  if [ "$current_sha" = "$target_sha" ]; then
    ok "当前已经是最新版本"
  else
    count=$(git rev-list --count "HEAD..$target" 2>/dev/null || printf '?')
    printf '相差提交：%s\n' "$count"
    warn "存在可用更新"
  fi
}

command_update() {
  [ "$#" -eq 0 ] || die "update 不接受版本参数；它始终更新到最新正式版本"
  require_linux
  require_docker
  require_git
  require_initialized
  require_clean_tree

  git fetch --tags "$DEPLOY_REMOTE" "$DEPLOY_BRANCH"
  target=$(latest_target)
  target_sha=$(git rev-parse --verify "$target^{commit}" 2>/dev/null) || die "找不到版本：$target"
  if [ "$target_sha" = "$(git rev-parse HEAD)" ]; then
    ok "当前已经是目标版本"
    return
  fi

  info "切换到版本 $target"
  git switch --detach "$target_sha"
  command_up
  ok "已更新到 $target ($(current_git_version))"
}

command_stop() {
  require_docker
  require_initialized
  load_runtime_images
  compose down --remove-orphans
  ok "服务已停止；数据卷和镜像均已保留"
}

remove_compose_resources() {
  project=$1
  for container in $(docker ps -aq --filter "label=com.docker.compose.project=$project"); do
    docker rm --force "$container"
  done
  for network in $(docker network ls -q --filter "label=com.docker.compose.project=$project"); do
    docker network rm "$network"
  done
  for volume in $(docker volume ls -q --filter "label=com.docker.compose.project=$project"); do
    docker volume rm "$volume"
  done
}

remove_project_images() {
  repositories="
xianyu-pilot-api
xianyu-pilot-web
xianyu-pilot-crawler
ghcr.io/hongliyuu/xianyu-pilot-api
ghcr.io/hongliyuu/xianyu-pilot-web
ghcr.io/hongliyuu/xianyu-pilot-crawler
"
  for repository in $repositories; do
    for image in $(docker image ls --filter "reference=$repository:*" --format '{{.Repository}}:{{.Tag}}'); do
      docker image rm --force "$image"
    done
  done
}

command_uninstall() {
  require_linux
  require_docker
  [ -n "$PROJECT_DIR" ] && [ "$PROJECT_DIR" != "/" ] || die "拒绝在无效项目目录执行卸载"

  warn "将永久删除本项目的容器、网络、数据卷、项目镜像、.env、secrets/ 和 .deploy/。"
  warn "MySQL/Redis 基础镜像、Docker 全局缓存和源码仓库不会删除。"
  [ -t 0 ] || die "uninstall 必须在交互式终端中执行"
  printf '请输入 %s 确认卸载：' "$PROJECT_NAME"
  IFS= read -r confirmation || die "未读取到卸载确认"
  [ "$confirmation" = "$PROJECT_NAME" ] || die "确认内容不匹配，已取消卸载"

  remove_compose_resources "$PROJECT_NAME"
  remove_project_images
  rm -rf "$STATE_DIR" "$PROJECT_DIR/secrets"
  rm -f "$ENV_FILE"
  ok "卸载完成；源码仓库和共享基础镜像已保留"
}

command=${1:-help}
[ "$#" -eq 0 ] || shift
case "$command" in
  help|-h|--help) show_help ;;
  init) [ "$#" -eq 0 ] || die "init 不接受参数"; command_init ;;
  up) [ "$#" -eq 0 ] || die "up 不接受参数"; command_up ;;
  status) [ "$#" -eq 0 ] || die "status 不接受参数"; command_status ;;
  logs) command_logs "$@" ;;
  check-update) [ "$#" -eq 0 ] || die "check-update 不接受参数"; command_check_update ;;
  update) command_update "$@" ;;
  stop) [ "$#" -eq 0 ] || die "stop 不接受参数"; command_stop ;;
  uninstall) [ "$#" -eq 0 ] || die "uninstall 不接受参数"; command_uninstall ;;
  *) die "未知命令：$command；执行 ./deploy.sh help 查看用法" ;;
esac
