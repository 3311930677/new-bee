# Expedition headless full regression runner (ASCII only - PS 5.1 reads scripts as ANSI)
# Usage: powershell -NoProfile -File tools/run_regression.ps1 [-Godot <exe>] [-Proj <dir>] [-Only <name>]
#
# Gotchas baked in here (do not "simplify" them away):
#  * Script must stay pure ASCII: PS 5.1 reads a BOM-less .ps1 as ANSI and mangled Chinese
#    paths once caused every item to fail ("d:\new bee\远征" -> "d:\new bee\杩滃緛").
#  * Do NOT switch to Start-Process: it re-splits -ArgumentList on spaces, so the project
#    path breaks ("Invalid project path specified: D:\new"). Use the & operator.
#  * --quit-after is hang insurance: if a verify script hits a compile error the coroutine
#    never reaches get_tree().quit(), and headless Godot would otherwise never exit.
param(
  [string]$Godot = "C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe",
  [string]$Proj  = "",
  [string]$Only  = "",
  [string]$List  = "",
  [int]$QuitAfter = 6000
)

if ($Proj -eq "") { $Proj = Split-Path -Parent $PSScriptRoot }
Write-Host ("Godot : " + $Godot)
Write-Host ("Project: " + $Proj)

if ($Only -ne "") { $List = $Only }

$scenes = @(
  "VerifyAssets","VerifyBattleScene","VerifyCity","VerifyGameHome",
  "VerifyMapScene","VerifyRouteScene","VerifyGacha","VerifyPanels","VerifyGrowth",
  "VerifyPerf","VerifyLore","VerifyQuests","VerifyAudio","VerifyTransit",
  "VerifyDrops","VerifyArena","VerifyAvatar"
)
$scripts = @("verify_data","verify_battle","verify_route","verify_trait","verify_walk_assets")

if ($List -ne "") {
  $wanted = @($List.Split(",") | ForEach-Object { $_.Trim() })
  $scenes  = @($scenes  | Where-Object { $wanted -contains $_ })
  $scripts = @($scripts | Where-Object { $wanted -contains $_ })
}

$fail = 0
foreach ($s in $scenes) {
  $out = (& $Godot --headless --path $Proj ("res://tools/" + $s + ".tscn") --quit-after $QuitAfter 2>&1 | Out-String)
  $ok  = ($out -match "_OK all tests passed") -or ($out -match "ASSETS_OK")
  $bad = ($out -match "FAIL:") -or ($out -match "ASSETS_FAIL") -or ($out -match "SCRIPT ERROR") `
         -or ($out -match "Parse Error") -or ($out -match "Compile Error")
  $status = "PASS"
  if ($bad -or -not $ok) { $status = "FAIL"; $fail++ }
  Write-Host ($status + "  " + $s)
  if ($status -eq "FAIL") {
    ($out -split "`n") | Where-Object { $_ -match "FAIL:|ERROR|SCRIPT|Parse|Compile" } |
      Select-Object -First 12 | ForEach-Object { Write-Host ("      " + $_.Trim()) }
  }
}
foreach ($s in $scripts) {
  $out = (& $Godot --headless --path $Proj -s ("res://tools/" + $s + ".gd") --quit-after $QuitAfter 2>&1 | Out-String)
  $ok  = ($out -match "OK") -and -not ($out -match "FAIL")
  $status = "PASS"
  if (-not $ok) { $status = "FAIL"; $fail++ }
  Write-Host ($status + "  " + $s)
  if ($status -eq "FAIL") {
    ($out -split "`n") | Where-Object { $_ -match "FAIL|ERROR" } |
      Select-Object -First 12 | ForEach-Object { Write-Host ("      " + $_.Trim()) }
  }
}
Write-Host ""
$total = $scenes.Count + $scripts.Count
if ($fail -eq 0) { Write-Host ("ALL GREEN  (" + $total + " items)") }
else { Write-Host ("FAILED: " + $fail + " / " + $total) }
exit $fail
