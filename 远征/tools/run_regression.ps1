# Expedition headless full regression runner (ASCII only - PS 5.1 reads BOM-less .ps1 as ANSI)
# Usage: powershell -NoProfile -File tools/run_regression.ps1 [-Godot <exe>] [-Proj <dir>] [-Only <name,...>]
#
# ---- Why this file looks over-engineered (issue #42) -------------------------------------
# The old runner reported ALL GREEN when it had run ZERO cases, ignored the process exit
# code, and accepted any "OK" substring as proof of success. A single "SCRIPT ERROR" printed
# after the OK line still counted as a pass. So "23 items ALL GREEN" was not evidence.
#
# Trust model now: a case passes ONLY when ALL of these hold
#   1. the godot process exit code is 0
#   2. the output contains THAT case's own completion line "<TOKEN>_OK ..." anchored at
#      line start (no substring guessing)
#   3. the output contains no failure marker and no engine error pattern
#   4. the case finished inside the wall-clock budget (--quit-after is a frame cap, not a
#      wall-clock cap; a wedged script still needs an external timeout)
#   5. the case did not write the real player save (user://save.json hash unchanged)
# The runner exits non-zero on: any failed case, unknown -Only name, a filter that matches
# nothing, a case count that differs from -Expected, or an engine that is not Godot 4.7.x.
#
# ---- Gotchas baked in here (do not "simplify" them away) ---------------------------------
#  * Script must stay pure ASCII: PS 5.1 reads a BOM-less .ps1 as ANSI and mangled Chinese
#    paths once caused every item to fail ("d:\new bee\<proj>" -> mojibake).
#  * Do NOT switch to Start-Process: it re-splits -ArgumentList on spaces, so a project path
#    containing spaces breaks ("Invalid project path specified: D:\new"). We build the
#    argument string ourselves and quote every element.
#  * .cmd/.bat engines are launched through cmd.exe (UseShellExecute=false can only start
#    real executables). That exists so tools/selftest_regression.ps1 can fault-inject this
#    runner with a fake engine.
param(
  [string]$Godot = "",
  [string]$Proj = "",
  [string]$Only = "",
  [string]$List = "",
  [int]$QuitAfter = 6000,
  [int]$TimeoutSec = 240,
  [int]$Expected = 35,
  [string]$LogDir = "",
  [switch]$AllowAnyVersion
)

$ErrorActionPreference = "Stop"

if ($Proj -eq "") { $Proj = Split-Path -Parent $PSScriptRoot }
if ($LogDir -eq "") { $LogDir = Join-Path $PSScriptRoot "_logs" }
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

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

# ---------------- engine version gate (#38): project targets Godot 4.7.x ----------------
$verOut = ""
try { $verOut = (& $Godot --version 2>&1 | Out-String).Trim() } catch { $verOut = "" }
if ($verOut -notmatch "4\.7\.") {
	if ($AllowAnyVersion) {
		Write-Host ("WARN: engine version is not 4.7.x: '" + $verOut + "' (allowed by -AllowAnyVersion)")
	} else {
		Write-Host ("FATAL: engine version must be 4.7.x, got '" + $verOut + "'. Exe: " + $Godot)
		exit 2
	}
}

# ---------------- case table (name, kind, completion token) ----------------
$cases = @(
	@{ N = "VerifyAssets";      K = "scene";  T = "ASSETS_OK" },
	@{ N = "VerifyBattleScene"; K = "scene";  T = "BATTLE_SCENE_OK" },
	@{ N = "VerifySave";        K = "scene";  T = "SAVE_OK" },
	@{ N = "VerifyUiLayout";    K = "scene";  T = "UI_LAYOUT_OK" },
	@{ N = "VerifySweep";       K = "scene";  T = "SWEEP_OK" },
	@{ N = "VerifyCity";        K = "scene";  T = "CITY_OK" },
	@{ N = "VerifyGameHome";    K = "scene";  T = "GAME_HOME_OK" },
	@{ N = "VerifyMapScene";    K = "scene";  T = "MAP_SCENE_OK" },
	@{ N = "VerifyMainWorld";   K = "scene";  T = "MAIN_WORLD_OK" },
	@{ N = "VerifyWorldSession";K = "scene";  T = "WORLD_SESSION_OK" },
	@{ N = "VerifyStory";       K = "scene";  T = "STORY_OK" },
	@{ N = "VerifyEconomy";     K = "scene";  T = "ECONOMY_OK" },
	@{ N = "VerifyTradeWorld";  K = "scene";  T = "TRADE_WORLD_OK" },
	@{ N = "VerifySecondAct";   K = "scene";  T = "SECOND_ACT_OK" },
	@{ N = "VerifyPortGrowth";  K = "scene";  T = "PORT_GROWTH_OK" },
	@{ N = "VerifyShipping";    K = "scene";  T = "SHIPPING_OK" },
	@{ N = "VerifyFishing";     K = "scene";  T = "FISHING_OK" },
	@{ N = "VerifyRouteScene";  K = "scene";  T = "ROUTE_SCENE_OK" },
	@{ N = "VerifyGacha";       K = "scene";  T = "GACHA_OK" },
	@{ N = "VerifyPanels";      K = "scene";  T = "PANELS_OK" },
	@{ N = "VerifyGrowth";      K = "scene";  T = "GROWTH_OK" },
	@{ N = "VerifyPerf";        K = "scene";  T = "PERF_OK" },
	@{ N = "VerifyLore";        K = "scene";  T = "LORE_OK" },
	@{ N = "VerifyQuests";      K = "scene";  T = "QUESTS_OK" },
	@{ N = "VerifyAudio";       K = "scene";  T = "AUDIO_OK" },
	@{ N = "VerifyTransit";     K = "scene";  T = "TRANSIT_OK" },
	@{ N = "VerifyDrops";       K = "scene";  T = "DROPS_OK" },
	@{ N = "VerifyArena";       K = "scene";  T = "ARENA_OK" },
	@{ N = "VerifyAvatar";      K = "scene";  T = "AVATAR_OK" },
	@{ N = "VerifyNav";         K = "scene";  T = "NAV_OK" },
	@{ N = "verify_data";       K = "script"; T = "DATA_OK" },
	@{ N = "verify_battle";     K = "script"; T = "BATTLE_OK" },
	@{ N = "verify_route";      K = "script"; T = "ROUTE_OK" },
	@{ N = "verify_trait";      K = "script"; T = "TRAIT_OK" },
	@{ N = "verify_walk_assets";K = "script"; T = "WALK_ASSETS_OK" }
)

# ---------------- filter: unknown names and empty result sets are errors ----------------
$filter = ""
if ($Only -ne "") { $filter = $Only } elseif ($List -ne "") { $filter = $List }
if ($filter -ne "") {
	$wanted = @($filter.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
	if ($wanted.Count -eq 0) {
		Write-Host ("FATAL: filter '" + $filter + "' contains no usable case name.")
		exit 2
	}
	$known = @($cases | ForEach-Object { $_.N })
	$unknown = @($wanted | Where-Object { $known -notcontains $_ })
	if ($unknown.Count -gt 0) {
		Write-Host ("FATAL: unknown case name(s): " + ($unknown -join ", "))
		Write-Host ("Known: " + ($known -join ", "))
		exit 2
	}
	$cases = @($cases | Where-Object { $wanted -contains $_.N })
}
$total = $cases.Count
if ($total -eq 0) {
	Write-Host "FATAL: 0 cases scheduled - refusing to report success for running nothing."
	exit 2
}
if ($filter -eq "" -and $Expected -gt 0 -and $total -ne $Expected) {
	Write-Host ("FATAL: expected " + $Expected + " cases, scheduled " + $total + ". Update -Expected if a case was added or removed on purpose.")
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
		# Fake engine support for fault injection (see tools/selftest_regression.ps1).
		# '/S ... "..."' is mandatory: without it cmd.exe strips the first and last quote of
		# the command line and then treats the whole remainder as one filename, which fails
		# with "the filename, directory name, or volume label syntax is incorrect".
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

# ---------------- locate user:// so we can prove the real save was untouched ----------------
$userDir = ""
$pre = Join-Path $PSScriptRoot "print_user_dir.gd"
if (Test-Path $pre) {
	$r0 = Invoke-Engine -Exe $Godot -ArgList @("--headless", "--path", $Proj, "-s", "res://tools/print_user_dir.gd", "--quit-after", "120") -TimeoutSec 60 -WorkDir $Proj
	foreach ($line in ($r0.Out -split "`r?`n")) {
		if ($line -match "^USER_DIR=(.+)$") { $userDir = $Matches[1].Trim() }
	}
}
$realSave = ""
$saveHash = ""
if ($userDir -ne "") {
	$cand = Join-Path $userDir "save.json"
	if (Test-Path $cand) {
		$realSave = $cand
		$saveHash = (Get-FileHash $realSave -Algorithm SHA256).Hash
	}
}

Write-Host ("Godot  : " + $Godot)
Write-Host ("Version: " + $verOut)
Write-Host ("Project: " + $Proj)
Write-Host ("UserDir: " + $(if ($userDir -ne "") { $userDir } else { "<unknown>" }))
Write-Host ("Cases  : " + $total + "  (timeout " + $TimeoutSec + "s, quit-after " + $QuitAfter + " frames)")
Write-Host ("Logs   : " + $LogDir)
try { $commit = (& git -C $Proj rev-parse --short HEAD 2>$null | Out-String).Trim() } catch { $commit = "" }
if ($commit -ne "") { Write-Host ("Commit : " + $commit) }
Write-Host ""

$errPatterns = @(
	"SCRIPT ERROR", "Parse Error", "Compile Error", "USER ERROR", "FATAL ERROR",
	"Assertion failed", "ERROR:", "FAIL:", "MISS:", "_FAIL"
)
# Godot prints these unconditionally while tearing the process down. They are a real signal
# (ref-counted resources still alive at exit) but they are emitted by the engine's shutdown
# path, not by any assertion, so they must not turn a green case red. They are counted and
# reported separately instead; see issue #43 in docs/2026-09-20-问题清单.md.
$exitNoise = @(
	"were leaked at exit", "resources still in use at exit"
)
$noiseCases = 0
$noiseLines = 0

$fail = 0
foreach ($c in $cases) {
	$name = $c.N
	$args = @("--headless", "--path", $Proj)
	if ($c.K -eq "scene") { $args += ("res://tools/" + $name + ".tscn") }
	else { $args += @("-s", ("res://tools/" + $name + ".gd")) }
	$args += @("--quit-after", [string]$QuitAfter)

	$r = Invoke-Engine -Exe $Godot -ArgList $args -TimeoutSec $TimeoutSec -WorkDir $Proj
	$out = $r.Out
	$log = Join-Path $LogDir ($name + ".log")
	try { Set-Content -Path $log -Value $out -Encoding UTF8 } catch {}

	$reasons = @()
	if ($r.TimedOut) {
		$reasons += ("timeout: no exit within " + $TimeoutSec + "s")
	} elseif ($r.Code -ne 0) {
		$reasons += ("exit code " + $r.Code)
	}
	$okRe = "(?m)^\s*" + $c.T + "\b"
	# -cmatch (case sensitive) on purpose: PowerShell's -match is case-INsensitive, so "_FAIL"
	# also matched the identifier "_mig_fail" inside a push_warning backtrace and turned a green
	# case red. Engine error strings have fixed capitalisation, so exact case is the safe test.
	if (-not ($out -cmatch $okRe)) {
		$reasons += ("missing completion line '" + $c.T + "'")
	}
	$sigErr = @{}
	$caseNoise = 0
	foreach ($line in ($out -split "`r?`n")) {
		$t = $line.Trim()
		if ($t -eq "") { continue }
		$isNoise = $false
		foreach ($n in $exitNoise) { if ($t -cmatch [regex]::Escape($n)) { $isNoise = $true } }
		if ($isNoise) { $caseNoise++; continue }
		foreach ($p in $errPatterns) {
			if ($t -cmatch [regex]::Escape($p)) { $sigErr[$p] = $true }
		}
	}
	if ($caseNoise -gt 0) { $noiseCases++; $noiseLines += $caseNoise }
	foreach ($p in $errPatterns) {
		if ($sigErr.ContainsKey($p)) { $reasons += ("output contains [" + $p + "]") }
	}
	if ($realSave -ne "" -and (Test-Path $realSave)) {
		$h = (Get-FileHash $realSave -Algorithm SHA256).Hash
		if ($h -ne $saveHash) {
			$reasons += "real player save.json was modified by this case"
			$saveHash = $h
		}
	}

	if ($reasons.Count -eq 0) {
		Write-Host ("PASS  " + $name)
	} else {
		$fail++
		Write-Host ("FAIL  " + $name + "  <- " + ($reasons -join "; "))
		$lines = @($out -split "`r?`n")
		$shown = 0
		$seen = @{}
		foreach ($line in $lines) {
			$t = $line.Trim()
			if ($t -eq "") { continue }
			$isNoise = $false
			foreach ($n in $exitNoise) { if ($t -cmatch [regex]::Escape($n)) { $isNoise = $true } }
			if ($isNoise) { continue }
			$hitErr = $false
			foreach ($p in $errPatterns) { if ($t -cmatch [regex]::Escape($p)) { $hitErr = $true } }
			if ($hitErr) {
				if ($seen.ContainsKey($t)) { continue }
				$seen[$t] = $true
				Write-Host ("      " + $t)
				$shown++
				if ($shown -ge 12) { break }
			}
		}
		if ($shown -eq 0) {
			foreach ($line in $lines) {
				$t = $line.Trim()
				if ($t -ne "") { Write-Host ("      " + $t); $shown++ }
				if ($shown -ge 8) { break }
			}
		}
		Write-Host ("      log: " + $log)
	}
}

Write-Host ""
if ($noiseCases -gt 0) {
	Write-Host ("NOTE: " + $noiseCases + " case(s) emitted " + $noiseLines +
		" engine exit-time resource diagnostic(s) (leaked RIDs / resources still in use)." +
		" Not counted as failures - tracked as issue #43.")
}
if ($realSave -ne "") {
	Write-Host ("NOTE: real player save " + $realSave + " unchanged by this run.")
}
if ($fail -eq 0) {
	Write-Host ("ALL GREEN  (" + $total + " cases, every case: exit 0 + own _OK line + no error pattern)")
} else {
	Write-Host ("FAILED: " + $fail + " / " + $total)
}
if ($fail -eq 0) { exit 0 }
if ($fail -gt 125) { exit 125 }
exit $fail
