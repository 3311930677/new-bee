param(
    [string]$CandidatePath = (Join-Path $PSScriptRoot 'Yuanzheng-0.2.3-optimization-arm64.apk'),
    [string]$ProjectRoot = 'D:\new-bee\远征'
)
$ErrorActionPreference = 'Stop'
$unpackRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'runtime\package_content'))
New-Item -ItemType Directory -Path $unpackRoot -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$packageZip = [System.IO.Compression.ZipFile]::OpenRead($CandidatePath)
$assetCount = 0
$jsonCompared = 0
$mismatches = @()
try {
    foreach ($entry in $packageZip.Entries) {
        if (-not $entry.FullName.StartsWith('assets/') -or $entry.FullName.EndsWith('/')) { continue }
        $relativeName = $entry.FullName.Substring(7)
        $target = [IO.Path]::GetFullPath((Join-Path $unpackRoot $relativeName))
        if (-not $target.StartsWith($unpackRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Package path escaped inspection directory' }
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force | Out-Null
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        $assetCount++
        if ($relativeName.StartsWith('data/') -and $relativeName.EndsWith('.json')) {
            $source = Join-Path $ProjectRoot $relativeName
            if (Test-Path -LiteralPath $source) {
                $jsonCompared++
                if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $target).Hash) { $mismatches += $relativeName }
            }
        }
    }
} finally { $packageZip.Dispose() }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'InspectOptimizationPackage.gd') -Destination (Join-Path $unpackRoot 'InspectOptimizationPackage.gd')
& 'D:\new-bee\reports\experience_rework_20261026\runtime\Godot_console.exe' --headless --path $unpackRoot --script res://InspectOptimizationPackage.gd --log-file (Join-Path $PSScriptRoot 'package_runtime_final.log')
if ($LASTEXITCODE -ne 0) { throw 'Packaged runtime verification failed' }
$runtime = Get-Content -LiteralPath (Join-Path $unpackRoot 'package_runtime_results.json') -Raw | ConvertFrom-Json
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-24'
$signatureErrorPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $signature = & 'D:\new-bee\tools\android-sdk-mobile\build-tools\36.1.0\apksigner.bat' verify --verbose $CandidatePath 2>&1
    $signatureExit = $LASTEXITCODE
} finally { $ErrorActionPreference = $signatureErrorPreference }
$signature | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'signature_verification.log') -Encoding UTF8
if ($signatureExit -ne 0) { throw 'APK signature verification failed' }
$badging = & 'D:\new-bee\tools\android-sdk-mobile\build-tools\36.1.0\aapt.exe' dump badging $CandidatePath
$packageLine = @($badging | Where-Object { $_ -like 'package:*' })[0]
[ordered]@{
    package = $packageLine
    assets = $assetCount
    json_compared = $jsonCompared
    json_mismatches = $mismatches
    runtime_checks = $runtime.checks
    runtime_failures = $runtime.failures
    signature_verified = $true
    apk_bytes = (Get-Item -LiteralPath $CandidatePath).Length
    apk_sha256 = (Get-FileHash -LiteralPath $CandidatePath -Algorithm SHA256).Hash
} | ConvertTo-Json -Depth 5 | Tee-Object -FilePath (Join-Path $PSScriptRoot 'package_verification.json')
if ($jsonCompared -eq 0) { throw 'No source data files were compared' }
if ($mismatches.Count -gt 0 -or $runtime.failures.Count -gt 0) { throw 'Package verification contains mismatches' }

