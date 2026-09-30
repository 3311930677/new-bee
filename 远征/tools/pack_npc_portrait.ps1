# Resize a transparent ImageGen NPC bust into the game's 512x512 portrait slot.
# Keep the full-size source in image/first_act/source for future redraws.
param([Parameter(Mandatory=$true)][string]$Source,
      [Parameter(Mandatory=$true)][string]$Output)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Bitmap]::new($Source)
$dst = [System.Drawing.Bitmap]::new(512, 512, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$draw = [System.Drawing.Graphics]::FromImage($dst)
$draw.Clear([System.Drawing.Color]::Transparent)
$draw.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$draw.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
try {
    $scale = [math]::Min(512.0 / $src.Width, 512.0 / $src.Height)
    $w = [int][math]::Round($src.Width * $scale)
    $h = [int][math]::Round($src.Height * $scale)
    $box = [System.Drawing.Rectangle]::new([int][math]::Floor((512 - $w) / 2), 512 - $h, $w, $h)
    $draw.DrawImage($src, $box, [System.Drawing.Rectangle]::new(0, 0, $src.Width, $src.Height),
        [System.Drawing.GraphicsUnit]::Pixel)
    $dst.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $draw.Dispose(); $dst.Dispose(); $src.Dispose()
}
