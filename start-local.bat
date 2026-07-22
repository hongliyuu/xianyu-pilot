@echo off
chcp 65001 >nul
setlocal

cd /d "%~dp0"

if not exist .env (
    echo .env was not found. Run scripts\init-local-dev.ps1 first.
    exit /b 1
)

if not exist apps\api\.venv\Scripts\python.exe (
    echo Local API virtual environment was not found. Run scripts\bootstrap-local-dev.ps1 first.
    exit /b 1
)

where npm >nul 2>nul
if errorlevel 1 (
    echo npm was not found in PATH.
    exit /b 1
)

if not exist apps\web\node_modules\vite\bin\vite.js (
    echo Web dependencies were not found. Run scripts\bootstrap-local-dev.ps1 first.
    exit /b 1
)

if not exist apps\crawler\node_modules\typescript\bin\tsc (
    echo Crawler dependencies were not found. Run scripts\bootstrap-local-dev.ps1 first.
    exit /b 1
)

rem Keep local source services aligned with the Docker service ports.
set "XYA_WEB_PORT=12400"
set "XYA_WEB_HOST=127.0.0.1"
set "SERVER_HOST=127.0.0.1"
set "SERVER_PORT=12401"
set "CRAWLER_PORT=12402"
set "PORT=%CRAWLER_PORT%"
set "HOST=127.0.0.1"
set "CRAWLER_BASE_URL=http://127.0.0.1:%CRAWLER_PORT%"
set "CRAWLER_SERVICE_URL=http://127.0.0.1:%CRAWLER_PORT%"
set "VITE_API_PROXY_TARGET=http://127.0.0.1:%SERVER_PORT%"
set "VITE_UPLOAD_PROXY_TARGET=http://127.0.0.1:%SERVER_PORT%"
set "CORS_ALLOWED_ORIGINS=http://127.0.0.1:%XYA_WEB_PORT%,http://localhost:%XYA_WEB_PORT%"
set "CRAWLER_ALLOWED_ORIGINS=http://127.0.0.1:%XYA_WEB_PORT%,http://localhost:%XYA_WEB_PORT%"

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\local-dev.ps1 preflight
if errorlevel 1 (
    echo One or more local ports are already in use. Nothing was started.
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\local-dev.ps1 start
set "START_EXIT=%ERRORLEVEL%"
if not "%START_EXIT%"=="0" (
    echo Local stack startup failed. See output\local-dev for service logs.
    exit /b %START_EXIT%
)

echo Local stack is ready. Use status-local.bat or stop-local.bat to manage it.
exit /b 0
