param([string]$List = "title,login,home")
$godot = "C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
$proj = "d:/new bee/远征"
$shots = "$env:APPDATA/Godot/app_userdata/远征/shots"
$out = "$env:TEMP/ui_shots"
New-Item -ItemType Directory -Force -Path $out | Out-Null
foreach ($s in $List.Split(",")) {
  $s = $s.Trim()
  if ($s -eq "") { continue }
  & $godot --path $proj res://tools/ShotRunner.tscn -- --scene=$s --frames=45 2>&1 | Out-Null
  if (Test-Path "$shots/$s.png") { Copy-Item "$shots/$s.png" "$out/ui_$s.png" -Force ; Write-Output "OK $s" }
  else { Write-Output "MISS $s" }
}
