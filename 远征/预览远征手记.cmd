@echo off
chcp 65001 >nul
set "APPDATA=%~dp0Godot\introduction_runtime\roaming"
set "LOCALAPPDATA=%~dp0Godot\introduction_runtime\local"
start "" "%~dp0..\工具\godot_4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." res://tools/PreviewIntroduction.tscn -- %*
