param([switch]$ShowWindow,[switch]$NoAudio)
$ErrorActionPreference='Stop'
$workspaceRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sdkRoot=Join-Path $workspaceRoot 'tools\android-sdk-mobile'
$emulatorPath=Join-Path $sdkRoot 'emulator\emulator.exe'
$avdPath=Join-Path $sdkRoot 'avd\Yuanzheng_Android17.ini'
if(-not (Test-Path -LiteralPath $emulatorPath) -or -not (Test-Path -LiteralPath $avdPath)) {
    throw 'Android 17 SDK or AVD is missing. See tools/android-emulator/README.md.'
}
$env:ANDROID_HOME=$sdkRoot
$env:ANDROID_SDK_ROOT=$sdkRoot
$env:ANDROID_USER_HOME=Join-Path $sdkRoot 'user'
$env:ANDROID_AVD_HOME=Join-Path $sdkRoot 'avd'
$logRoot=Join-Path $workspaceRoot 'reports\android_emulator_20261024'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$arguments=@('-avd','Yuanzheng_Android17','-no-snapshot','-no-boot-anim','-gpu','host','-memory','4096','-cores','4','-port','5554')
if(-not $ShowWindow) { $arguments+='-no-window' }
if($NoAudio) { $arguments+='-no-audio' }
$proxyState=Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
if($proxyState.ProxyEnable -eq 1 -and $proxyState.ProxyServer -match '^([^=;]+):(\d+)$') {
    $arguments+=@('-http-proxy',('http://'+$proxyState.ProxyServer))
}
$style='Normal'
if(-not $ShowWindow) { $style='Hidden' }
$process=Start-Process -FilePath $emulatorPath -ArgumentList $arguments -WindowStyle $style -RedirectStandardOutput (Join-Path $logRoot 'emulator_current_stdout.log') -RedirectStandardError (Join-Path $logRoot 'emulator_current_stderr.log') -PassThru
Write-Output ('Android 17 emulator PID: '+$process.Id)
