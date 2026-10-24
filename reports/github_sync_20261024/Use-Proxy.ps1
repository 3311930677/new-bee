$proxyState=Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
if(-not $env:HTTP_PROXY -and -not $env:HTTPS_PROXY -and -not $env:ALL_PROXY -and $proxyState.ProxyEnable -eq 1 -and $proxyState.ProxyServer -match '^([^=;]+):(\d+)$') {
    $env:HTTP_PROXY='http://'+$proxyState.ProxyServer
    $env:HTTPS_PROXY=$env:HTTP_PROXY
}

