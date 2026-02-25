@echo off
setlocal
chcp 65001 >nul 2>&1
:: CCR Dashboard Launcher

set "SERVER_JS=%USERPROFILE%\.claude\presets\dashboard\server.js"
if not exist "%SERVER_JS%" set "SERVER_JS=%~dp0server.js"

echo.
echo  CCR Dashboard Launcher
echo  ========================
echo.

if not exist "%SERVER_JS%" (
    echo  [ERR] Dashboard server.js not found
    echo  [INFO] Expected: %USERPROFILE%\.claude\presets\dashboard\server.js
    exit /b 1
)

:: Check if CCR is running
netstat -ano | findstr "LISTENING" | findstr ":3000 " >nul 2>&1
if errorlevel 1 (
    where ccr >nul 2>&1
    if errorlevel 1 (
        echo  [ERR] ccr command not found in PATH
        echo  [INFO] Install with: npm install -g @musistudio/claude-code-router
        exit /b 1
    )

    echo  [*] Starting CCR...
    start /b ccr start >nul 2>&1
    timeout /t 2 /nobreak >nul
    echo  [OK] CCR started on port 3000
) else (
    echo  [OK] CCR already running on port 3000
)

:: Check if dashboard is already running
netstat -ano | findstr "LISTENING" | findstr ":3456 " >nul 2>&1
if errorlevel 1 (
    echo  [*] Starting Dashboard...
    node "%SERVER_JS%"
) else (
    echo  [OK] Dashboard already running
    echo  [*] Opening http://localhost:3456
    start http://localhost:3456
)
