$ErrorActionPreference='Stop'
$workspaceRoot='D:\new-bee'
$reportRoot=Join-Path $workspaceRoot 'reports\android_export_lock_20261024'
$runtimePath='C:\Users\tsz\.codex\visualizations\2026\10\23\01a1693b-f9a3-7d92-a039-cbf364dea934\mobile_fixes_build_qa\runtime'
$env:APPDATA=$runtimePath
$env:LOCALAPPDATA=$runtimePath
$env:JAVA_HOME='C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot'
$env:TEMP=Join-Path $workspaceRoot 'tools\android-sdk-mobile\export_tmp'
$env:TMP=$env:TEMP
$godotPath=Join-Path $workspaceRoot 'tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$outputPath=Join-Path $workspaceRoot '远征\exports\android\Yuanzheng-0.2.1-mobile2.apk'
& $godotPath --headless --path (Join-Path $workspaceRoot '远征') --log-file (Join-Path $reportRoot 'export.log') --export-debug Android $outputPath *> (Join-Path $reportRoot 'export_console.log')
$buildExit=$LASTEXITCODE
Write-Output ('Godot export exit: '+$buildExit)
if($buildExit -ne 0){Get-Content -LiteralPath (Join-Path $reportRoot 'export_console.log') -Tail 28; exit $buildExit}
Get-Item -LiteralPath $outputPath | Select-Object FullName,Length,LastWriteTime

