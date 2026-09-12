# APK 远程探测脚本：不下载整包，只按 HTTP Range 读取 ZIP 目录区和指定小文件
# 用法:
#   .\apk_probe.ps1 -Url <apk地址> -ListOnly          仅列出文件清单
#   .\apk_probe.ps1 -Url <apk地址>                     列清单 + 拉取配置类文件并扫描其中的服务器地址
param(
    [Parameter(Mandatory = $true)][string]$Url,
    [switch]$ListOnly,
    [int]$MaxFetch = 250
)

$ErrorActionPreference = "Stop"

function Get-Range([string]$u, [long]$from, [long]$to) {
    for ($try = 1; $try -le 3; $try++) {
        try {
            $r = [Net.HttpWebRequest]::Create($u)
            $r.Method = "GET"
            $r.AddRange($from, $to)
            $r.Timeout = 30000
            $r.ReadWriteTimeout = 60000
            $resp = $r.GetResponse()
            $ms = New-Object IO.MemoryStream
            $resp.GetResponseStream().CopyTo($ms)
            $resp.Close()
            return , $ms.ToArray()
        } catch {
            if ($try -eq 3) { throw } else { Start-Sleep -Milliseconds (400 * $try) }
        }
    }
}

function Get-Total([string]$u) {
    $r = [Net.HttpWebRequest]::Create($u)
    $r.Method = "GET"
    $r.AddRange(0, 0)
    $r.Timeout = 30000
    $resp = $r.GetResponse()
    $cr = $resp.Headers[[Net.HttpResponseHeader]::ContentRange]
    $resp.Close()
    if ($cr -and $cr -match "/(\d+)$") { return [int64]$Matches[1] }
    return -1
}

# --- 1. 总大小 ---
$total = Get-Total $Url
Write-Output ("APK 总大小: {0:N0} bytes" -f $total)
$apkName = ($Url -split "/")[-1]
$outDir = "d:\战场女神\工具\apk_probe_" + ($apkName -replace "\W", "_").Substring(0, 20)
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# --- 2. 拉取尾部 256KB，解析 EOCD / ZIP64 ---
$tailLen = [Math]::Min(262144, $total)
$tail = Get-Range $Url ($total - $tailLen) ($total - 1)

$eocd = -1
for ($i = $tail.Length - 22; $i -ge 0; $i--) {
    if ($tail[$i] -eq 0x50 -and $tail[$i+1] -eq 0x4B -and $tail[$i+2] -eq 0x05 -and $tail[$i+3] -eq 0x06) { $eocd = $i; break }
}
if ($eocd -lt 0) { throw "未找到 ZIP EOCD" }
[long]$cdSize = [BitConverter]::ToUInt32($tail, $eocd + 12)
[long]$cdOffset = [BitConverter]::ToUInt32($tail, $eocd + 16)

# ZIP64 EOCD 记录 (PK0606)，若存在则以其为准
for ($i = $tail.Length - 56; $i -ge 0; $i--) {
    if ($tail[$i] -eq 0x50 -and $tail[$i+1] -eq 0x4B -and $tail[$i+2] -eq 0x06 -and $tail[$i+3] -eq 0x06) {
        $cdSize = [BitConverter]::ToInt64($tail, $i + 40)
        $cdOffset = [BitConverter]::ToInt64($tail, $i + 48)
        Write-Output "检测到 ZIP64 格式"
        break
    }
}
Write-Output ("目录区: offset={0}, size={1}" -f $cdOffset, $cdSize)

# --- 3. 拉取目录区并解析全部条目 ---
$cd = Get-Range $Url $cdOffset ($cdOffset + $cdSize - 1)
Write-Output ("调试: CD拉回 {0} 字节, 前4字节: {1:X2} {2:X2} {3:X2} {4:X2}" -f $cd.Length, $cd[0], $cd[1], $cd[2], $cd[3])
$entries = New-Object System.Collections.Generic.List[object]
$i = 0
while ($i + 46 -le $cd.Length) {
    if (-not ($cd[$i] -eq 0x50 -and $cd[$i+1] -eq 0x4B -and $cd[$i+2] -eq 0x01 -and $cd[$i+3] -eq 0x02)) { break }
    [int]$method = [BitConverter]::ToUInt16($cd, $i + 10)
    [long]$csize = [BitConverter]::ToUInt32($cd, $i + 20)
    [long]$usize = [BitConverter]::ToUInt32($cd, $i + 24)
    [int]$nlen = [BitConverter]::ToUInt16($cd, $i + 28)
    [int]$elen = [BitConverter]::ToUInt16($cd, $i + 30)
    [int]$clen = [BitConverter]::ToUInt16($cd, $i + 32)
    [long]$lho = [BitConverter]::ToUInt32($cd, $i + 42)
    $name = [Text.Encoding]::UTF8.GetString($cd, $i + 46, $nlen)
    $entries.Add([PSCustomObject]@{ name = $name; method = $method; csize = $csize; usize = $usize; lho = $lho })
    $i += 46 + $nlen + $elen + $clen
}
Write-Output ("条目总数: {0}" -f $entries.Count)

# 顶层目录分布
$entries | ForEach-Object { ($_.name -split "/")[0] } | Group-Object | Sort-Object Count -Descending | Select-Object -First 12 | ForEach-Object { "{0,7}  {1}" -f $_.Count, $_.Name }

$listPath = Join-Path $outDir "filelist.csv"
$entries | Export-Csv $listPath -NoTypeInformation -Encoding UTF8
Write-Output ("完整清单已保存: {0}" -f $listPath)

if ($ListOnly) { return }

# --- 4. 筛选配置类候选并逐个拉取扫描 ---
$cand = $entries | Where-Object {
    $_.name -match '\.(json|xml|properties|cfg|conf|ini|txt|url|list|mrp|ver|dat)$' -and
    $_.usize -gt 0 -and $_.usize -le 2097152 -and
    $_.name -notmatch '^(res/|META-INF/|lib/|androidx/|kotlin/|assets/res/)'
} | Select-Object -First $MaxFetch
Write-Output ("配置类候选: {0} 个，开始拉取扫描..." -f $cand.Count)

$rx = '(?:https?://[^\s"\x00-\x1f<>]+|\b(?:[a-z0-9\-]+\.)+(?:com|cn|net|org|cc|top|xyz|vip)\b(?::\d{1,5})?|\b\d{1,3}(?:\.\d{1,3}){3}(?::\d{1,5})?\b)'
$found = @()
$n = 0
foreach ($e in $cand) {
    $n++
    try {
        $lh = Get-Range $Url $e.lho ($e.lho + 29)
        if (-not ($lh[0] -eq 0x50 -and $lh[1] -eq 0x4B)) { continue }
        $ln = [BitConverter]::ToUInt16($lh, 26)
        $le = [BitConverter]::ToUInt16($lh, 28)
        $dstart = $e.lho + 30 + $ln + $le
        $data = Get-Range $Url $dstart ($dstart + $e.csize - 1)
        $out = $null
        if ($e.method -eq 8) {
            $ms = New-Object IO.MemoryStream(, $data)
            $ds = New-Object IO.Compression.DeflateStream($ms, [IO.Compression.CompressionMode]::Decompress)
            $os = New-Object IO.MemoryStream
            $ds.CopyTo($os)
            $out = $os.ToArray()
        } else { $out = $data }
        $text = [Text.Encoding]::UTF8.GetString($out)
        $ms2 = [regex]::Matches($text, $rx) | ForEach-Object { $_.Value } | Where-Object { $_ -notmatch 'schemas\.android|w3\.org|apache\.org|example\.' } | Sort-Object -Unique
        if ($ms2) {
            $found += "== {0} ({1} bytes) ==" -f $e.name, $e.usize
            $found += ($ms2 | Select-Object -First 15)
        }
    } catch { }
    if ($n % 25 -eq 0) { Write-Output ("  ...已扫描 {0}/{1}" -f $n, $cand.Count) }
}
$report = Join-Path $outDir "server_hits.txt"
$found | Out-File $report -Encoding UTF8
Write-Output ("扫描完成，结果已保存: {0}" -f $report)
$found
