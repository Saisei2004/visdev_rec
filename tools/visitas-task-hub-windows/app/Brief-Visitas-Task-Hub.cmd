@echo off
setlocal
cd /d "%~dp0"
py -3 taskctl.py --actor human sync
py -3 taskctl.py --actor human brief
