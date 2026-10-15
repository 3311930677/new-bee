# 重新导入改动过的素材并截取主城首页（480x800 / 480x1067）
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path (Split-Path -Parent $projectRoot) 'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$env:APPDATA = Join-Path $projectRoot 'Godot/reference_preview_runtime'
& $engine --headless --path $projectRoot --import 2>&1 | Out-Null
$log = & $engine --path $projectRoot 'res://tools/CaptureTownHome.tscn' 2>&1 | Out-String -Width 300
$log -split "`n" | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|TOWN_HOME' }
