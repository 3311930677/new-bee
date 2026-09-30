# Mechanical alpha-bounds packing; preserves source art and alpha, uses nearest sampling.
param([Parameter(Mandatory=$true)][string]$Source,
      [Parameter(Mandatory=$true)][string]$Output,
      [int]$Width=256, [int]$Height=192)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Bitmap]::new($Source)
$dst = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$draw = [System.Drawing.Graphics]::FromImage($dst)
try {
    $minX=$src.Width; $minY=$src.Height; $maxX=-1; $maxY=-1
    for ($y=0; $y -lt $src.Height; $y++) {
        for ($x=0; $x -lt $src.Width; $x++) {
            if ($src.GetPixel($x,$y).A -gt 8) {
                $minX=[math]::Min($minX,$x); $maxX=[math]::Max($maxX,$x)
                $minY=[math]::Min($minY,$y); $maxY=[math]::Max($maxY,$y)
            }
        }
    }
    if ($maxY -lt 0) { throw 'No visible sprite pixels' }
    $cropW=$maxX-$minX+1; $cropH=$maxY-$minY+1
    $scale=[math]::Min(($Width-8.0)/$cropW,($Height-8.0)/$cropH)
    $outW=[int][math]::Round($cropW*$scale); $outH=[int][math]::Round($cropH*$scale)
    $outX=[int][math]::Floor(($Width-$outW)/2); $outY=$Height-4-$outH
    $draw.Clear([System.Drawing.Color]::Transparent)
    $draw.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $draw.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $draw.DrawImage($src,[System.Drawing.Rectangle]::new($outX,$outY,$outW,$outH),
        [System.Drawing.Rectangle]::new($minX,$minY,$cropW,$cropH),[System.Drawing.GraphicsUnit]::Pixel)
    $dst.Save($Output,[System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output ("SPRITE_PACKED {0}x{1} foot={2}" -f $Width,$Height,($Height-4))
} finally { $draw.Dispose(); $dst.Dispose(); $src.Dispose() }
