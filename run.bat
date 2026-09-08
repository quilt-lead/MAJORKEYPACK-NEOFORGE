@echo off
cd /d "%~dp0"
setlocal

echo.
echo ========================================
echo       MAJOR KEY PACK SERVER START
echo          NEOFORGE 1.21.1
echo ========================================
echo.

echo [1/3] Scanning mods and updating manifest...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scan_mods.ps1"

if errorlevel 1 (
    echo.
    echo ERROR: Mod scan failed.
    pause
    exit /b 1
)

echo.
echo [2/3] Updating GitHub...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-github.ps1"

if errorlevel 1 (
    echo.
    echo ERROR: GitHub update failed.
    pause
    exit /b 1
)

echo.
echo ========================================
echo       STARTING MINECRAFT SERVER
echo ========================================
echo.

call "%~dp0run.bat"

echo.
echo ========================================
echo       MINECRAFT SERVER STOPPED
echo ========================================
echo.

pause