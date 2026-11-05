@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_exe.ps1"
if errorlevel 1 (
    echo.
    echo Falha ao gerar o executavel.
)
pause
