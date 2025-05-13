@echo off
setlocal

set SCRIPT_NAME=AutoNtwrk_TAB.ps1
set TASK_NAME=Network Checker
set RUN_CLOCK=15
set SCRIPT_PATH=%~dp0%SCRIPT_NAME%

echo Installing Task Scheduler task for %SCRIPT_NAME%...

:: Create the task to run every 15 mins
schtasks /Create /TN "%TASK_NAME%" /TR "powershell -ExecutionPolicy Bypass -File \"%SCRIPT_PATH%\"" /SC MINUTE /MO %RUN_CLOCK% /RL HIGHEST /F

echo.
echo Installed. The script will now run every %RUN_CLOCK% minutes.
echo.
pause