# Expedition main-world playthrough runner (ASCII only - PS 5.1 reads BOM-less .ps1 as ANSI)
# Usage: powershell -NoProfile -File tools/run_playthrough.ps1 [-Godot <exe>] [-Proj <dir>] [-Roles zs,fs]
#
# What this proves (review issue R-06):
#   On a fresh save, the whole real-input chain of s01..s12 is walked and the player returns to
#   the city. Along the way the tool really wins / loses / flees a fight, really fills the bag
#   so a drop lands in the pending box, and really hands in a quest item. Then the process is
#   killed for real and a SECOND process reopens the SAME temp save and checks that every step
#   can continue and that rewards were banked exactly once (ledger idempotency across processes).
#
# Hard rules baked in here (do not "simplify" them away):
#   * This runner NEVER touches the real player save. Every run records the SHA256 of
#     user://save.json before and after and fails if it changed.
#   * The playthrough tool is NOT part of the 29-case regression table and must not be added to
#     tools/run_regression.ps1.
#   * Phase A quits the process on its own; the wrapper copies the phase-A temp save to the
#     phase-B temp save and starts a brand new process for phase B.
#   * Keep this file pure ASCII: PS 5.1 reads a BOM-less .ps1 as ANSI, and the project path
#     contains a space and CJK characters.
param(
  [string]$Godot = "",
  [string]$Proj = "",
  [string]$Roles = "zs,fs",
  [switch]$Act2,
  [switch]$Act3Front,
  [switch]$Act3,
  [switch]$ThirdSide,
  [switch]$Companions,
  [switch]$CampaignGrowth,
  [switch]$CampaignGear,
  [string]$SourceDir = "",
  [int]$TimeoutSec = 2400,
  [string]$LogDir = ""
)

$ErrorActionPreference = "Stop"

if ($Proj -eq "") { $Proj = Split-Path -Parent $PSScriptRoot }
if ($LogDir -eq "") { $LogDir = Join-Path $PSScriptRoot "_logs" }
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
if (($ThirdSide -or $Companions -or $CampaignGrowth) -and ($SourceDir -eq "" -or -not (Test-Path -LiteralPath $SourceDir -PathType Container))) {
    Write-Host "FATAL: continuation requires an existing -SourceDir with verified s01-s28 saves."
    exit 2
}

# ---------------- engine resolution: explicit > env > known installs ----------------
$explicitGodot = ($Godot -ne "")
if ($Godot -eq "") { $Godot = $env:GODOT_EXE }
if ($Godot -ne "" -and -not (Test-Path $Godot) -and $explicitGodot) {
	Write-Host ("FATAL: -Godot does not exist: " + $Godot)
	exit 2
}
if ($Godot -eq "" -or -not (Test-Path $Godot)) {
	$cands = @(
		(Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"),
		"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe",
		"D:\godot\Godot_v4.7.2-stable_win64.exe",
		"D:\godot\Godot_v4.7-stable_win64.exe"
	)
	$found = ""
	foreach ($c in $cands) { if ($found -eq "" -and $c -and (Test-Path $c)) { $found = $c } }
	if ($found -eq "") {
		Write-Host "FATAL: Godot exe not found. Pass -Godot <exe> or set GODOT_EXE."
		exit 2
	}
	$Godot = $found
}

$verOut = ""
try { $verOut = (& $Godot --version 2>&1 | Out-String).Trim() } catch { $verOut = "" }
if ($verOut -notmatch "4\.7\.") {
	Write-Host ("FATAL: engine version must be 4.7.x, got '" + $verOut + "'. Exe: " + $Godot)
	exit 2
}

# ---------------- process helper: exit code + wall clock timeout ----------------
function Invoke-Engine {
	param([string]$Exe, [string[]]$ArgList, [int]$TimeoutSec, [string]$WorkDir)
	$sb = New-Object System.Text.StringBuilder
	foreach ($a in $ArgList) { [void]$sb.Append('"').Append([string]$a.Replace('"', '\"')).Append('" ') }
	$argStr = $sb.ToString()
	$psi = New-Object System.Diagnostics.ProcessStartInfo
	$psi.UseShellExecute = $false
	$psi.RedirectStandardOutput = $true
	$psi.RedirectStandardError = $true
	$psi.CreateNoWindow = $true
	$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
	$psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
	if ($WorkDir) { $psi.WorkingDirectory = $WorkDir }
	if ($Exe -match '\.(cmd|bat)$') {
		$psi.FileName = "cmd.exe"
		$psi.Arguments = '/D /S /C "' + '"' + $Exe + '" ' + $argStr.Trim() + '"'
	} else {
		$psi.FileName = $Exe
		$psi.Arguments = $argStr
	}
	$p = New-Object System.Diagnostics.Process
	$p.StartInfo = $psi
	[void]$p.Start()
	$so = $p.StandardOutput.ReadToEndAsync()
	$se = $p.StandardError.ReadToEndAsync()
	$finished = $p.WaitForExit($TimeoutSec * 1000)
	$code = -999
	if (-not $finished) {
		try { $p.Kill() } catch {}
		[void]$p.WaitForExit(5000)
	} else {
		try { $code = $p.ExitCode } catch { $code = -998 }
	}
	$o = ""
	$e = ""
	try { [void]$so.Wait(5000); $o = $so.Result } catch {}
	try { [void]$se.Wait(5000); $e = $se.Result } catch {}
	try { $p.Dispose() } catch {}
	return @{ Out = ($o + $e); Code = $code; TimedOut = (-not $finished) }
}

function Get-UserDir {
	param([string]$Exe, [string]$Proj)
	$ud = ""
	$pre = Join-Path $PSScriptRoot "print_user_dir.gd"
	if (-not (Test-Path $pre)) { return "" }
	$r0 = Invoke-Engine -Exe $Exe -ArgList @("--headless", "--path", $Proj, "-s", "res://tools/print_user_dir.gd", "--quit-after", "120") -TimeoutSec 60 -WorkDir $Proj
	foreach ($line in ($r0.Out -split "`r?`n")) {
		if ($line -match "^USER_DIR=(.+)$") { $ud = $Matches[1].Trim() }
	}
	return $ud
}

# ---------------- real player save: hash before / after ----------------
$userDir = Get-UserDir -Exe $Godot -Proj $Proj
$realSave = ""
$hashBefore = ""
if ($userDir -ne "") {
	$cand = Join-Path $userDir "save.json"
	if (Test-Path $cand) {
		$realSave = $cand
		$hashBefore = (Get-FileHash $realSave -Algorithm SHA256).Hash
	}
}

$errPatterns = @(
	"SCRIPT ERROR", "Parse Error", "Compile Error", "USER ERROR", "FATAL ERROR",
	"Assertion failed", "ERROR:", "FAIL:", "MISS:", "_FAIL"
)
$exitNoise = @("were leaked at exit", "resources still in use at exit")

function Test-Output {
	param([string]$Out, [string]$Token, [string[]]$ErrPatterns, [string[]]$Noise)
	$reasons = @()
	if (-not ($Out -cmatch ("(?m)^\s*" + $Token + "\b"))) {
		$reasons += ("missing completion line '" + $Token + "'")
	}
	foreach ($line in ($Out -split "`r?`n")) {
		$t = $line.Trim()
		if ($t -eq "") { continue }
		$isNoise = $false
		foreach ($n in $Noise) { if ($t -cmatch [regex]::Escape($n)) { $isNoise = $true } }
		if ($isNoise) { continue }
		if ($t -cmatch "(^|\s)PLAY_BAD(\s|$)") { $reasons += ("PLAY_BAD reported: " + $t) }
		foreach ($p in $ErrPatterns) {
			if ($t -cmatch [regex]::Escape($p)) { $reasons += ("output contains [" + $p + "]") }
		}
	}
	return $reasons
}

function Get-TokenJson {
	param([string]$Out, [string]$Token)
	foreach ($line in ($Out -split "`r?`n")) {
		if ($line.StartsWith($Token + " ")) { return $line.Substring($Token.Length + 1).Trim() }
	}
	return ""
}

$roleList = @($Roles.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
if ($roleList.Count -eq 0) {
	Write-Host "FATAL: -Roles contains no usable role id."
	exit 2
}

Write-Host ("Godot   : " + $Godot)
Write-Host ("Version : " + $verOut)
Write-Host ("Project : " + $Proj)
Write-Host ("UserDir : " + $(if ($userDir -ne "") { $userDir } else { "<unknown>" }))
Write-Host ("Roles   : " + ($roleList -join ", "))
Write-Host ("Timeout : " + $TimeoutSec + "s per process call")
Write-Host ("Logs    : " + $LogDir)
if ($realSave -ne "") {
	Write-Host ("RealSave: " + $realSave)
	Write-Host ("Hash    : " + $hashBefore)
} else {
	Write-Host "RealSave: <none found before run>"
}
Write-Host ""

$fail = 0
$allOk = $true

foreach ($role in $roleList) {
	Write-Host ("==== role " + $role + " ====")
	$saveA = Join-Path $LogDir ("save_playthrough_" + $role + "_a.json")
	$saveB = Join-Path $LogDir ("save_playthrough_" + $role + "_b.json")

	# ---- phase A: walk the whole chain and persist ----
	$playScene = "res://tools/PlaythroughMainWorld.tscn"
	if ($ThirdSide) { $playScene = "res://tools/PlaythroughThirdSide.tscn" }
	if ($Companions) { $playScene = "res://tools/PlaythroughCompanions.tscn" }
	if ($CampaignGrowth) { $playScene = "res://tools/PlaythroughCampaignGrowth.tscn" }
	if ($CampaignGear) { $playScene = "res://tools/PlaythroughCampaignGear.tscn" }
	$argsA = @("--headless", "--path", $Proj, $playScene, "--", $role, "a")
	if ($ThirdSide -or $Companions -or $CampaignGrowth -or ($CampaignGear -and $SourceDir -ne "")) { $argsA += ("--source-dir=" + [System.IO.Path]::GetFullPath($SourceDir)) }
	if ($Act3) { $argsA += "act3" } elseif ($Act3Front) { $argsA += "act3_front" } elseif ($Act2) { $argsA += "act2" }
	$argsA += ("--save-dir=" + [System.IO.Path]::GetFullPath($LogDir))
	$ra = Invoke-Engine -Exe $Godot -ArgList $argsA -TimeoutSec $TimeoutSec -WorkDir $Proj
	$logA = Join-Path $LogDir ("playthrough_" + $role + "_a.log")
	try { Set-Content -Path $logA -Value $ra.Out -Encoding UTF8 } catch {}
	Write-Host ("  phase A log: " + $logA)

	$rea = @()
	if ($ra.TimedOut) { $rea += ("timeout after " + $TimeoutSec + "s") }
	elseif ($ra.Code -ne 0) { $rea += ("exit code " + $ra.Code) }
	$rea += (Test-Output -Out $ra.Out -Token "PLAY_A_OK" -ErrPatterns $errPatterns -Noise $exitNoise)
	if ($rea.Count -ne 0) {
		Write-Host ("  FAIL phase A: " + ($rea -join "; "))
		foreach ($line in ($ra.Out -split "`r?`n")) {
			$t = $line.Trim()
			if ($t -cmatch "(^|\s)PLAY_(BAD|STUCK|EVENT|SETUP|MAP)\b") { Write-Host ("      " + $t) }
		}
		$fail++
		$allOk = $false
		continue
	}
	$stateA = Get-TokenJson -Out $ra.Out -Token "PLAY_A_STATE"
	Write-Host "  phase A OK"

	if (-not (Test-Path $saveA)) {
		Write-Host ("  FAIL: phase A temp save missing: " + $saveA)
		$fail++
		$allOk = $false
		continue
	}

	# ---- hand the phase-A temp save to phase B as a brand new process ----
	try { Copy-Item -Path $saveA -Destination $saveB -Force } catch {
		Write-Host ("  FAIL: cannot copy temp save for phase B: " + $_.Exception.Message)
		$fail++
		$allOk = $false
		continue
	}

	# ---- phase B: reopen the SAME save in a NEW process and verify ----
	$argsB = @("--headless", "--path", $Proj, $playScene, "--", $role, "b")
	if ($Act3) { $argsB += "act3" } elseif ($Act3Front) { $argsB += "act3_front" } elseif ($Act2) { $argsB += "act2" }
	$argsB += ("--save-dir=" + [System.IO.Path]::GetFullPath($LogDir))
	$rb = Invoke-Engine -Exe $Godot -ArgList $argsB -TimeoutSec $TimeoutSec -WorkDir $Proj
	$logB = Join-Path $LogDir ("playthrough_" + $role + "_b.log")
	try { Set-Content -Path $logB -Value $rb.Out -Encoding UTF8 } catch {}
	Write-Host ("  phase B log: " + $logB)

	$reb = @()
	if ($rb.TimedOut) { $reb += ("timeout after " + $TimeoutSec + "s") }
	elseif ($rb.Code -ne 0) { $reb += ("exit code " + $rb.Code) }
	$reb += (Test-Output -Out $rb.Out -Token "PLAY_B_OK" -ErrPatterns $errPatterns -Noise $exitNoise)
	if ($reb.Count -eq 0) { $reb += (Test-Output -Out $rb.Out -Token "PLAY_OK" -ErrPatterns $errPatterns -Noise $exitNoise) }
	if ($reb.Count -ne 0) {
		Write-Host ("  FAIL phase B: " + ($reb -join "; "))
		foreach ($line in ($rb.Out -split "`r?`n")) {
			$t = $line.Trim()
			if ($t -cmatch "(^|\s)PLAY_(BAD|STUCK|EVENT|SETUP|MAP)\b") { Write-Host ("      " + $t) }
		}
		$fail++
		$allOk = $false
		continue
	}
	$stateB = Get-TokenJson -Out $rb.Out -Token "PLAY_B_STATE"
	if ($stateA -ne "" -and $stateB -ne "" -and $stateA -ne $stateB) {
		Write-Host "  FAIL: phase A/B state mismatch (a save was not carried across processes)"
		Write-Host ("      A: " + $stateA)
		Write-Host ("      B: " + $stateB)
		$fail++
		$allOk = $false
		continue
	}
	Write-Host "  phase B OK"
	Write-Host ("  PASS role " + $role)
	Write-Host ""
}

# ---------------- real player save must be untouched ----------------
if ($realSave -ne "" -and (Test-Path $realSave)) {
	$hashAfter = (Get-FileHash $realSave -Algorithm SHA256).Hash
	if ($hashAfter -ne $hashBefore) {
		Write-Host ("FAIL: real player save was modified! before=" + $hashBefore + " after=" + $hashAfter)
		$allOk = $false
		$fail++
	} else {
		Write-Host ("RealSave hash unchanged: " + $hashAfter)
	}
}

Write-Host ""
if ($allOk) {
	Write-Host ("PLAYTHROUGH_ALL_OK (" + $roleList.Count + " roles, A+B per role, real save untouched)")
	exit 0
}
Write-Host ("PLAYTHROUGH_FAILED: " + $fail + " problem(s)")
if ($fail -gt 125) { exit 125 }
exit $fail
