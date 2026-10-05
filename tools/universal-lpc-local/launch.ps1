$ErrorActionPreference = 'Stop'
$lpcDir = $PSScriptRoot
$lpcPython = 'D:\anaconda\python.exe'
$lpcUrl = 'http://127.0.0.1:18764/'
try {
    Invoke-WebRequest -Uri $lpcUrl -UseBasicParsing -TimeoutSec 2 | Out-Null
} catch {
    Start-Process -FilePath $lpcPython -ArgumentList ('"' + (Join-Path $lpcDir 'server.py') + '"') -WorkingDirectory $lpcDir -WindowStyle Hidden -RedirectStandardOutput (Join-Path $lpcDir 'server.log') -RedirectStandardError (Join-Path $lpcDir 'server-error.log')
    Start-Sleep -Seconds 2
}
Start-Process $lpcUrl
