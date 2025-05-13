@echo off
setlocal

set SCRIPT_NAME=AutoNtwrk.ps1
set TASK_NAME=Network Checker
set SCRIPT_PATH=%~dp0%SCRIPT_NAME%

echo Installing Task Scheduler task for SSID Checker...

:: Create the task to run at logon
schtasks /Create /TN "%TASK_NAME%" /TR "powershell -ExecutionPolicy Bypass -File \"%SCRIPT_PATH%\"" /SC ONLOGON /RL HIGHEST /F

echo.
echo Installed. The script will now run at user logon.
echo.
pause