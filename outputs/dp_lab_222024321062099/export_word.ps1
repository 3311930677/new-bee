$ErrorActionPreference = 'Stop'
$reportRoot = 'D:\new-bee\outputs\dp_lab_222024321062099'
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
try {
    $report = $word.Documents.Open("$reportRoot\222024321062099谈世钊.docx", $false, $true)
    $report.Repaginate()
    $report.ExportAsFixedFormat("$reportRoot\qa\report.pdf", 17)
    $pageCount = $report.ComputeStatistics(2)
    Write-Output "Rendered pages: $pageCount"
    for ($pageIndex=1; $pageIndex -le $pageCount; $pageIndex++) {
        $startRange = $report.GoTo(1,1,$pageIndex)
        if ($pageIndex -lt $pageCount) {
            $endRange = $report.GoTo(1,1,($pageIndex+1))
            $pageRange = $report.Range($startRange.Start,$endRange.Start)
        } else { $pageRange = $report.Range($startRange.Start,$report.Content.End) }
        $pageText = $pageRange.Text.Replace([char]13,' ').Replace([char]12,' ')
        Write-Output ("Page {0}: {1} chars | {2}" -f $pageIndex,$pageText.Length,$pageText.Substring(0,[Math]::Min(95,$pageText.Length)))
    }
    $report.Close(0)
} finally { $word.Quit() }
