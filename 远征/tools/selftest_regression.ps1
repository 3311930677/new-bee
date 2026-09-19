# Expedition regression RUNNER self-test (ASCII only - PS 5.1 reads BOM-less .ps1 as ANSI)
# Usage: powershell -NoProfile -File tools/selftest_regression.ps1
#
# Purpose (issue #42): never trust "ALL GREEN" until the runner has been proven to FAIL on
# every way a case can lie about success. This script drives tools/run_regression.ps1 with
# fake "engine" batches that emit crafted output, and asserts the verdict for each.
#
# Fake engines are .cmd files: run_regression.ps1 launches them through cmd.exe so that a
# non-executable can stand in for godot.exe during fault injection.
param([switch]$KeepLogs)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$tmp = Join-Path $env:TEMP "expedition_runner_selftest"
if (Test-Path $tmp) { Remove-Item -Path $tmp -Recurse -Force }
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

# Batch layout note: the --version branch uses goto instead of "&". cmd's handling of "&"
# inside an "if" body is ambiguous, and we need the version branch to be the ONLY thing that
# runs when the runner probes the engine version.
function Write-Fixture {
	param([string]$Name, [string]$Version, [string[]]$Body)
	$path = Join-Path $tmp ($Name + ".cmd")
	$lines = New-Object System.Collections.ArrayList
	[void]$lines.Add("@echo off")
	[void]$lines.Add('if not "%1"=="--version" goto case')
	[void]$lines.Add("echo " + $Version)
	[void]$lines.Add("exit /b 0")
	[void]$lines.Add(":case")
	foreach ($b in $Body) { [void]$lines.Add($b) }
	[void]$lines.Add("exit /b 0")
	Set-Content -Path $path -Value ($lines -join "`r`n") -Encoding ASCII
	return $path
}

$good     = Write-Fixture "good"             "4.7.2-stable" @('echo ASSETS_OK all textures resolved')
$okErr    = Write-Fixture "ok_then_error"    "4.7.2-stable" @('echo ASSETS_OK all textures resolved', 'echo SCRIPT ERROR: parse error: boom')
$okExit1  = Write-Fixture "ok_but_exit1"     "4.7.2-stable" @('echo ASSETS_OK all textures resolved', 'exit /b 1')
$noMark   = Write-Fixture "no_marker"        "4.7.2-stable" @('echo hello world')
$failMark = Write-Fixture "fail_marker"      "4.7.2-stable" @('echo ASSETS_FAIL', 'exit /b 1')
$oldVer   = Write-Fixture "old_version"      "4.6.1-stable" @('echo ASSETS_OK all textures resolved')
$hang     = Write-Fixture "hang"             "4.7.2-stable" @('ping -n 21 127.0.0.1 > nul', 'echo ASSETS_OK all textures resolved')

$checks = 0
$fails = 0

function Assert-Case {
	param([string]$Title, [string[]]$RunnerArgs, [int]$WantExit, [string]$WantText, [int]$TimeoutSec)
	$script:checks++
	$argList = @("-NoProfile", "-File", ".\run_regression.ps1") + $RunnerArgs
	if ($TimeoutSec -gt 0) { $argList += @("-TimeoutSec", [string]$TimeoutSec) }
	$out = ""
	$code = -1
	$sw = [System.Diagnostics.Stopwatch]::StartNew()
	try {
		$out = (& powershell @argList 2>&1 | Out-String)
		$code = $LASTEXITCODE
	} catch {
		$out = "EXCEPTION: " + $_.Exception.Message
	}
	$sw.Stop()
	$problem = ""
	if ($WantExit -ge 0 -and $code -ne $WantExit) { $problem += ("exit " + $code + " (want " + $WantExit + "); ") }
	if ($WantExit -eq 0 -and $code -ne 0) { $problem += "expected success; " }
	if ($WantExit -gt 0 -and $code -eq 0) { $problem += "expected failure but runner succeeded; " }
	if ($WantText -ne "" -and ($out -notmatch [regex]::Escape($WantText))) { $problem += ("missing text [" + $WantText + "]; ") }
	if ($problem -eq "") {
		Write-Host ("PASS  " + $Title + "  (" + [int]$sw.Elapsed.TotalSeconds + "s)")
	} else {
		$script:fails++
		Write-Host ("FAIL  " + $Title + "  <- " + $problem)
		$lines = @($out -split "`r?`n")
		$n = 0
		foreach ($line in $lines) {
			$t = $line.Trim()
			if ($t -eq "") { continue }
			Write-Host ("      " + $t)
			$n++
			if ($n -ge 8) { break }
		}
	}
}

Write-Host "== regression runner fault injection =="
Write-Host ""

Assert-Case "clean case passes"                -RunnerArgs @("-Only","VerifyAssets","-Godot",$good)    -WantExit 0   -WantText "PASS  VerifyAssets"
Assert-Case "OK followed by SCRIPT ERROR fails" -RunnerArgs @("-Only","VerifyAssets","-Godot",$okErr)   -WantExit 1   -WantText "FAIL  VerifyAssets"
Assert-Case "OK marker but exit code 1 fails"   -RunnerArgs @("-Only","VerifyAssets","-Godot",$okExit1) -WantExit 1   -WantText "exit code 1"
Assert-Case "exit 0 without completion line"    -RunnerArgs @("-Only","VerifyAssets","-Godot",$noMark)  -WantExit 1   -WantText "missing completion line"
Assert-Case "engine printed a FAIL marker"      -RunnerArgs @("-Only","VerifyAssets","-Godot",$failMark)-WantExit 1   -WantText "output contains [_FAIL]"
Assert-Case "wedged case is killed by timeout"  -RunnerArgs @("-Only","VerifyAssets","-Godot",$hang)    -WantExit 1   -WantText "timeout" -TimeoutSec 5
Assert-Case "unknown case name is an error"     -RunnerArgs @("-Only","NoSuchCase","-Godot",$good)      -WantExit 2   -WantText "unknown case name"
Assert-Case "empty filter is an error"          -RunnerArgs @("-List",",","-Godot",$good)               -WantExit 2   -WantText "no usable case name"
Assert-Case "missing -Godot exe is an error"    -RunnerArgs @("-Only","VerifyAssets","-Godot","C:\no\such\godot.exe") -WantExit 2 -WantText "does not exist"
Assert-Case "engine not 4.7.x is an error"      -RunnerArgs @("-Only","VerifyAssets","-Godot",$oldVer)  -WantExit 2   -WantText "must be 4.7.x"
Assert-Case "-AllowAnyVersion lets 4.6 run"     -RunnerArgs @("-Only","VerifyAssets","-Godot",$oldVer,"-AllowAnyVersion") -WantExit 0 -WantText "PASS  VerifyAssets"

Write-Host ""
if ($fails -eq 0) {
	Write-Host ("RUNNER SELFTEST GREEN (" + $checks + " fault-injection checks)")
} else {
	Write-Host ("RUNNER SELFTEST FAILED: " + $fails + " / " + $checks)
}

if (-not $KeepLogs) {
	if (Test-Path $tmp) { Remove-Item -Path $tmp -Recurse -Force }
}
if ($fails -eq 0) { exit 0 }
exit $fails
