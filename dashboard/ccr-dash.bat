@echo off
chcp 65001 >nul 2>&1
:: CCR Dashboard Launcher

echo.
echo  CCR Dashboard Launcher
echo  ========================
echo.

:: Check if CCR is running
netstat -ano | findstr "LISTENING" | findstr ":3000 " >nul 2>&1
if errorlevel 1 (
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
    node "c:\Apps\claude-presets\dashboard\server.js"
) else (
    echo  [OK] Dashboard already running
    echo  [*] Opening http://localhost:3456
    start http://localhost:3456
)
