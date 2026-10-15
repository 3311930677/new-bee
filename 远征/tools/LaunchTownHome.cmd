@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0LaunchTownHome.ps1" -Height 800
if errorlevel 1 pause
