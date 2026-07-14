@echo off
setlocal
cd /d "%~dp0"
py -3 taskctl.py --actor sync sync >> "%LOCALAPPDATA%\VisitasTaskHub\sync.log" 2>&1
exit /b %ERRORLEVEL%
