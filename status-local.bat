@echo off
setlocal

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\local-dev.ps1 status
exit /b %ERRORLEVEL%
