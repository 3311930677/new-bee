# Pack an ImageGen four-cell horizontal idle sheet into the game's 512x128 atlas.
# The source art remains in image/first_act/source so the result can be rebuilt.
param([Parameter(Mandatory=$true)][string]$Source,
      [Parameter(Mandatory=$true)][string]$Output)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Bitmap]::new($Source)
$dst = [System.Drawing.Bitmap]::new(512, 128, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$draw = [System.Drawing.Graphics]::FromImage($dst)
$draw.Clear([System.Drawing.Color]::Transparent)
$draw.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$draw.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
try {
    for ($i = 0; $i -lt 4; $i++) {
        $left = [int][math]::Floor($src.Width * $i / 4)
        $right = [int][math]::Floor($src.Width * ($i + 1) / 4) - 1
        $minX = $right; $maxX = $left; $minY = $src.Height; $maxY = -1
        for ($y = 0; $y -lt $src.Height; $y++) {
            for ($x = $left; $x -le $right; $x++) {
                if ($src.GetPixel($x, $y).A -gt 8) {
                    if ($x -lt $minX) { $minX = $x }
                    if ($x -gt $maxX) { $maxX = $x }
                    if ($y -lt $minY) { $minY = $y }
                    if ($y -gt $maxY) { $maxY = $y }
                }
            }
        }
        if ($maxY -lt 0) { throw "Frame $i has no visible pixels" }
        $w = $maxX - $minX + 1; $h = $maxY - $minY + 1
        $scale = [math]::Min(108.0 / $w, 116.0 / $h)
        $outW = [int][math]::Round($w * $scale)
        $outH = [int][math]::Round($h * $scale)
        $outX = 128 * $i + [int][math]::Floor((128 - $outW) / 2)
        $outY = 123 - $outH
        $target = [System.Drawing.Rectangle]::new($outX, $outY, $outW, $outH)
        $sourceRect = [System.Drawing.Rectangle]::new($minX, $minY, $w, $h)
        $draw.DrawImage($src, $target, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
    }
    $dst.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $draw.Dispose(); $dst.Dispose(); $src.Dispose()
}
