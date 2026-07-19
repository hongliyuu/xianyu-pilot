#!/bin/sh
# 首次启动初始化向导：自动生成所有 secrets 文件、bcrypt admin 密码 hash 和 .env。
# 安全设计：所有随机值都从 /dev/urandom 读取；密码 hash 用 bcrypt cost 12；
# secrets 目录权限 0700，文件权限 0600。已存在的文件不会被覆盖。
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_DIR"

SECRETS_DIR="./secrets"
DEFAULT_ADMIN_PASSWORD="admin123"

color() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
info()  { printf '%s %s\n' "$(color '1;36' '•')" "$*"; }
warn()  { printf '%s %s\n' "$(color '1;33' '!')" "$*" >&2; }
ok()    { printf '%s %s\n' "$(color '1;32' '✓')" "$*"; }
die()   { printf '%s %s\n' "$(color '1;31' '✗')" "$*" >&2; exit 1; }

# ---------- 1. 前置依赖检查 ----------
# 生成 secrets 不需要 Docker；只有 bcrypt 生成在主机无 Python 时才退到 Docker 容器
# 检查 openssl（生成随机数用，几乎所有 Unix 都自带）
command -v openssl >/dev/null 2>&1 || command -v head >/dev/null 2>&1 || die "未检测到 openssl/head，无法生成随机密钥"

# ---------- 2. 创建 secrets 目录 ----------
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR" 2>/dev/null || true

# 生成 base64url 随机字符串（A-Za-z0-9_-，符合 Redis 密码正则要求）
gen_random() {
  bytes=${1:-32}
  # 32 bytes → ~43 字符；64 bytes → ~86 字符；均满足 >=32 字符要求
  head -c "$bytes" /dev/urandom | base64 | tr -d '\n=' | tr '+/' '-_'
}

# 写入 secret 文件（已存在且非空则跳过）
# 权限 0644：docker-compose secrets file 模式下，容器内进程（如 mysql 用户）需要读取权限
# 开源版单用户部署场景下可接受；多用户服务器请用 docker secrets environment 模式
write_secret() {
  file=$1
  content=$2
  if [ -s "$file" ]; then
    return 0
  fi
  printf '%s' "$content" > "$file"
  chmod 644 "$file" 2>/dev/null || true
}

# 生成空的可选 secret 文件（已存在则跳过）
touch_optional() {
  file=$1
  if [ ! -f "$file" ]; then
    : > "$file"
    chmod 644 "$file" 2>/dev/null || true
  fi
}

# ---------- 3. 生成必需的随机 secrets ----------
info "生成随机 secrets（如已存在则跳过）..."

# 3 组 MySQL 密码必须互不相同且 >=16 字符；gen_random 32 bytes 输出 ~43 字符，远超要求
write_secret "$SECRETS_DIR/mysql-root-password"       "$(gen_random 32)"
write_secret "$SECRETS_DIR/mysql-app-password"        "$(gen_random 32)"
write_secret "$SECRETS_DIR/mysql-migration-password"  "$(gen_random 32)"
# Redis 密码必须 Base64URL 字符
write_secret "$SECRETS_DIR/redis-password"            "$(gen_random 32)"
# JWT/Cookie/Token 必须 >=32 字符
write_secret "$SECRETS_DIR/jwt-secret"                "$(gen_random 64)"
write_secret "$SECRETS_DIR/cookie-crypto-secret"      "$(gen_random 64)"
write_secret "$SECRETS_DIR/internal-api-token"        "$(gen_random 64)"

# ---------- 4. 生成空的可选 secrets（功能未启用时也需要文件存在） ----------
touch_optional "$SECRETS_DIR/commercial-backend-access-token"
touch_optional "$SECRETS_DIR/embedding-api-key"
touch_optional "$SECRETS_DIR/ai-provider-api-key"
touch_optional "$SECRETS_DIR/amap-api-key"

# ---------- 5. 生成 admin bcrypt 密码 hash ----------
ADMIN_PASSWORD="${ADMIN_PASSWORD:-$DEFAULT_ADMIN_PASSWORD}"

if [ -s "$SECRETS_DIR/admin-password-hash" ]; then
  ok "admin-password-hash 已存在（跳过生成）"
else
  info "生成 admin bcrypt 密码 hash（cost 12）..."

  # 防止密码注入：用环境变量传给子进程
  export ADMIN_PASSWORD

  hash_value=""
  # 优先用主机 Python（已装 bcrypt）
  python_cmd=""
  if command -v python3 >/dev/null 2>&1 && python3 -c "import bcrypt" 2>/dev/null; then
    python_cmd="python3"
  elif command -v python >/dev/null 2>&1 && python -c "import bcrypt" 2>/dev/null; then
    python_cmd="python"
  fi

  if [ -n "$python_cmd" ]; then
    hash_value=$($python_cmd -c '
import os, bcrypt
pw = os.environ["ADMIN_PASSWORD"].encode("utf-8")
print(bcrypt.hashpw(pw, bcrypt.gensalt(rounds=12)).decode())
')
  else
    # 主机有 Python 但没装 bcrypt → 尝试 pip install --user bcrypt
    pip_cmd=""
    if command -v python3 >/dev/null 2>&1; then
      pip_cmd="python3"
    elif command -v python >/dev/null 2>&1; then
      pip_cmd="python"
    fi

    if [ -n "$pip_cmd" ] && $pip_cmd -m pip --version >/dev/null 2>&1; then
      info "尝试安装 bcrypt 包（pip install --user bcrypt）..."
      if $pip_cmd -m pip install --user --quiet bcrypt 2>/dev/null; then
        hash_value=$($pip_cmd -c '
import os, bcrypt
pw = os.environ["ADMIN_PASSWORD"].encode("utf-8")
print(bcrypt.hashpw(pw, bcrypt.gensalt(rounds=12)).decode())
')
      fi
    fi

    # 仍然失败 → 退到 Docker 临时容器
    if [ -z "$hash_value" ]; then
      if command -v docker >/dev/null 2>&1; then
        info "主机未安装 Python bcrypt，使用 Docker 临时容器生成（首次约 30s）..."
        hash_value=$(docker run --rm -e ADMIN_PASSWORD python:3.11-slim sh -c '
          pip install --quiet --no-cache-dir bcrypt 2>/dev/null
          python -c "
import os, bcrypt
pw = os.environ[\"ADMIN_PASSWORD\"].encode(\"utf-8\")
print(bcrypt.hashpw(pw, bcrypt.gensalt(rounds=12)).decode())
"
        ')
      else
        die "无法生成 bcrypt hash：主机无 Python bcrypt 包，也未安装 Docker。请任选其一：\n  1) pip install --user bcrypt 后重跑\n  2) 安装 Docker 后重跑\n  3) 在已装 bcrypt 的机器上生成 hash，手动写入 ./secrets/admin-password-hash"
      fi
    fi
  fi

  [ -n "$hash_value" ] || die "bcrypt hash 生成失败"
  printf '%s' "$hash_value" > "$SECRETS_DIR/admin-password-hash"
  chmod 644 "$SECRETS_DIR/admin-password-hash" 2>/dev/null || true
  # 保存用于最终输出的明文密码（仅当前会话），然后 unset 环境变量
  DISPLAY_PASSWORD="$ADMIN_PASSWORD"
  unset ADMIN_PASSWORD
fi

# ---------- 6. 创建 .env ----------
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    cp .env.example .env
    ok "已从 .env.example 创建 .env"
  else
    die ".env.example 不存在，无法创建 .env"
  fi
else
  ok ".env 已存在（跳过创建）"
fi

# ---------- 7. 完成 ----------
# DISPLAY_PASSWORD 在生成 hash 时设置；如果 hash 文件已存在（跳过生成），用默认值
DISPLAY_PASSWORD="${DISPLAY_PASSWORD:-$DEFAULT_ADMIN_PASSWORD}"

cat <<EOF

$(ok "初始化完成")

默认管理员账号：
  用户名：admin
  密码：${DISPLAY_PASSWORD}

$(warn "请尽快登录后修改默认密码！")

下一步：
  启动服务：sh ./start.sh
  或手动：docker compose pull && docker compose up -d

EOF
