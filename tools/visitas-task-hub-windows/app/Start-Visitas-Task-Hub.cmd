@echo off
setlocal
cd /d "%~dp0"
py -3 server.py --port 7700 --open
