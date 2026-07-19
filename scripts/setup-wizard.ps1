# 首次启动初始化向导（Windows PowerShell 版本）
# 自动生成所有 secrets 文件、bcrypt admin 密码 hash 和 .env
# 用法：在仓库根目录执行 .\scripts\setup-wizard.ps1
#Requires -Version 5.1
[CmdletBinding()]
param(
  [string]$AdminPassword = "admin123"
)

$ErrorActionPreference = "Stop"
$ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $ProjectDir

$SecretsDir = Join-Path $ProjectDir "secrets"
$DefaultAdminPassword = $AdminPassword

function Write-Info { param([string]$Msg) Write-Host "• $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "✓ $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "! $Msg" -ForegroundColor Yellow }
function Write-Die  { param([string]$Msg) Write-Host "✗ $Msg" -ForegroundColor Red; exit 1 }

# ---------- 1. 前置依赖检查 ----------
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
  Write-Die "未检测到 Docker，请先安装：https://docs.docker.com/get-docker/"
}
$composeVersion = & docker compose version 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Die "未检测到 Docker Compose v2，请升级 Docker 或安装 docker-compose-plugin"
}

# ---------- 2. 创建 secrets 目录 ----------
# 注意：docker-compose secrets file 模式下，容器内进程（如 mysql 用户）需要读取权限
# 因此 secrets 文件权限不能是 0600（仅 owner 可读），Windows 不强制 chmod 但容器会继承 ACL
if (-not (Test-Path $SecretsDir)) {
  New-Item -ItemType Directory -Path $SecretsDir -Force | Out-Null
}

# 生成 base64url 随机字符串
function New-RandomSecret {
  param([int]$Bytes = 32)
  $buffer = New-Object byte[] $Bytes
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  $rng.GetBytes($buffer)
  $base64 = [Convert]::ToBase64String($buffer)
  # 转 base64url：去掉 = padding，+→-，/→_
  return $base64.TrimEnd('=').Replace('+','-').Replace('/','_')
}

# 写入 secret 文件（已存在且非空则跳过）
function Write-Secret {
  param([string]$File, [string]$Content)
  if (Test-Path $File) {
    $existing = Get-Content $File -Raw -ErrorAction SilentlyContinue
    if ($existing -and $existing.Trim().Length -gt 0) { return }
  }
  [System.IO.File]::WriteAllText($File, $Content)
}

# 生成空的可选 secret 文件
function Touch-Optional {
  param([string]$File)
  if (-not (Test-Path $File)) {
    [System.IO.File]::WriteAllText($File, "")
  }
}

# ---------- 3. 生成必需的随机 secrets ----------
Write-Info "生成随机 secrets（如已存在则跳过）..."

Write-Secret (Join-Path $SecretsDir "mysql-root-password")      (New-RandomSecret 32)
Write-Secret (Join-Path $SecretsDir "mysql-app-password")       (New-RandomSecret 32)
Write-Secret (Join-Path $SecretsDir "mysql-migration-password") (New-RandomSecret 32)
Write-Secret (Join-Path $SecretsDir "redis-password")           (New-RandomSecret 32)
Write-Secret (Join-Path $SecretsDir "jwt-secret")               (New-RandomSecret 64)
Write-Secret (Join-Path $SecretsDir "cookie-crypto-secret")     (New-RandomSecret 64)
Write-Secret (Join-Path $SecretsDir "internal-api-token")       (New-RandomSecret 64)

# ---------- 4. 生成空的可选 secrets ----------
Touch-Optional (Join-Path $SecretsDir "commercial-backend-access-token")
Touch-Optional (Join-Path $SecretsDir "embedding-api-key")
Touch-Optional (Join-Path $SecretsDir "ai-provider-api-key")
Touch-Optional (Join-Path $SecretsDir "amap-api-key")

# ---------- 5. 生成 admin bcrypt 密码 hash ----------
$hashFile = Join-Path $SecretsDir "admin-password-hash"
if (Test-Path $hashFile) {
  $existingHash = Get-Content $hashFile -Raw -ErrorAction SilentlyContinue
  if ($existingHash -and $existingHash.Trim().Length -gt 0) {
    Write-Ok "admin-password-hash 已存在（跳过生成）"
  } else {
    $needHash = $true
  }
} else {
  $needHash = $true
}

if ($needHash) {
  Write-Info "生成 admin bcrypt 密码 hash（cost 12）..."

  $env:ADMIN_PASSWORD = $DefaultAdminPassword
  $hashValue = ""

  # 优先用主机 Python
  $pythonCmd = $null
  foreach ($cmd in @("python", "python3", "py")) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) {
      $testBcrypt = & $cmd -c "import bcrypt" 2>$null
      if ($LASTEXITCODE -eq 0) {
        $pythonCmd = $cmd
        break
      }
    }
  }

  if ($pythonCmd) {
    $hashValue = & $pythonCmd -c @'
import os, bcrypt
pw = os.environ["ADMIN_PASSWORD"].encode("utf-8")
print(bcrypt.hashpw(pw, bcrypt.gensalt(rounds=12)).decode())
'@
  } else {
    # 退到 Docker 临时容器
    Write-Info "主机未安装 Python bcrypt，使用 Docker 临时容器生成..."
    $hashValue = & docker run --rm -e ADMIN_PASSWORD python:3.11-slim sh -c @"
pip install --quiet --no-cache-dir bcrypt 2>/dev/null
python -c 'import os, bcrypt; pw=os.environ[\"ADMIN_PASSWORD\"].encode(); print(bcrypt.hashpw(pw, bcrypt.gensalt(rounds=12)).decode())'
"@
  }

  Remove-Item Env:ADMIN_PASSWORD -ErrorAction SilentlyContinue

  if (-not $hashValue -or $hashValue.Trim().Length -eq 0) {
    Write-Die "bcrypt hash 生成失败"
  }
  [System.IO.File]::WriteAllText($hashFile, $hashValue.Trim())
}

# ---------- 6. 创建 .env ----------
$envFile = Join-Path $ProjectDir ".env"
$envExample = Join-Path $ProjectDir ".env.example"
if (-not (Test-Path $envFile)) {
  if (Test-Path $envExample) {
    Copy-Item $envExample $envFile
    Write-Ok "已从 .env.example 创建 .env"
  } else {
    Write-Die ".env.example 不存在，无法创建 .env"
  }
} else {
  Write-Ok ".env 已存在（跳过创建）"
}

# ---------- 7. 完成 ----------
Write-Host ""
Write-Ok "初始化完成"
Write-Host ""
Write-Host "默认管理员账号："
Write-Host "  用户名：admin"
Write-Host "  密码：$DefaultAdminPassword"
Write-Host ""
Write-Warn "请尽快登录后修改默认密码！"
Write-Host ""
Write-Host "下一步："
Write-Host "  启动服务：.\start.bat"
Write-Host "  或手动：docker compose pull ; docker compose up -d"
Write-Host ""
