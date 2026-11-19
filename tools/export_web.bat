@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0export_web.ps1" %*
pause
