param([int]$Height = 800)
# Town home preview. Height 800 = 480x800, 1067 = 20:9 tall phone.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $projectRoot
$engine = Join-Path $workspaceRoot 'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $engine)) { throw 'Bundled Godot engine not found.' }
$env:APPDATA = Join-Path $projectRoot 'Godot/reference_preview_runtime'
& $engine --path $projectRoot --resolution "480x$Height" 'res://tools/PreviewTownHome.tscn'
exit $LASTEXITCODE
