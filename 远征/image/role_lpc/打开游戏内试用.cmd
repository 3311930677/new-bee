@echo off
start "" "%~dp0..\..\..\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%~dp0..\.." res://src/preview/LpcWorldPreview.tscn --log-file "%~dp0review\interactive.log"
