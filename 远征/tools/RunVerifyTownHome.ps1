# 重新导入素材并运行正式版主城首页验收（有窗口，截图需要渲染）；日志写到 shots/town_home_20261013/verify.log
$ErrorActionPreference = 'Continue'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path (Split-Path -Parent $projectRoot) 'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$env:APPDATA = Join-Path $projectRoot 'Godot/reference_preview_runtime'
$log = Join-Path $projectRoot 'shots/town_home_20261013/verify.log'
& $engine --headless --path $projectRoot --import *> $null
& $engine --path $projectRoot 'res://tools/VerifyTownHome.tscn' *> $log
$code = $LASTEXITCODE
Select-String -Path $log -Pattern 'TOWN_|SCRIPT ERROR|Parse Error' -Encoding UTF8 | ForEach-Object { $_.Line }
"exit=$code"
