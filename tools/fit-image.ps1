# Crop-to-fill and resize a photo to one of the aspect ratios the site uses.
#
# System.Drawing rather than WPF: the shop's phone and camera JPEGs carry Sony
# Exif that WPF's decoder rejects outright ("Value does not fall within the
# expected range"), while System.Drawing reads them without complaint.
#
# -Focus is the vertical centre of the crop as a fraction of the source height.
# 0.5 centres it; a portrait photo whose subject sits low needs more. The same
# applies horizontally through -FocusX.
param(
  [Parameter(Mandatory = $true)][string]$Source,
  [Parameter(Mandatory = $true)][string]$Dest,
  [int]$Width  = 1200,
  [int]$Height = 800,
  [double]$Focus  = 0.5,
  [double]$FocusX = 0.5,
  [int]$Quality   = 86
)

Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Image]::FromFile((Resolve-Path $Source))

# Phone and camera JPEGs record which way up they were shot in Exif tag 0x0112
# rather than rotating the pixels. System.Drawing hands back the raw pixels and
# ignores the tag, so a portrait shot arrives on its side unless we rotate it
# here. Viewers that honour the tag show the source upright, which makes this
# easy to miss until the crop lands sideways on the page.
if ($src.PropertyIdList -contains 0x0112) {
  switch ($src.GetPropertyItem(0x0112).Value[0]) {
    2 { $src.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX) }
    3 { $src.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
    4 { $src.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipX) }
    5 { $src.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipX) }
    6 { $src.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
    7 { $src.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipX) }
    8 { $src.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
  }
}

# Pick the largest source rectangle matching the target ratio, then slide it
# over the focus point without letting it run off the edge.
$targetRatio = $Width / $Height
$srcRatio    = $src.Width / $src.Height

if ($srcRatio -gt $targetRatio) {
  $cropH = $src.Height
  $cropW = [int][Math]::Round($src.Height * $targetRatio)
} else {
  $cropW = $src.Width
  $cropH = [int][Math]::Round($src.Width / $targetRatio)
}

$x = [int][Math]::Round($src.Width  * $FocusX - $cropW / 2)
$y = [int][Math]::Round($src.Height * $Focus  - $cropH / 2)
$x = [Math]::Max(0, [Math]::Min($x, $src.Width  - $cropW))
$y = [Math]::Max(0, [Math]::Min($y, $src.Height - $cropH))

$out = New-Object System.Drawing.Bitmap($Width, $Height)
$out.SetResolution(72, 72)
$g = [System.Drawing.Graphics]::FromImage($out)
$g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

$g.DrawImage($src,
  (New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)),
  $x, $y, $cropW, $cropH,
  [System.Drawing.GraphicsUnit]::Pixel)

$codec  = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
          Where-Object { $_.MimeType -eq 'image/jpeg' }
$params = New-Object System.Drawing.Imaging.EncoderParameters(1)
$params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
  [System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)

$destDir = Split-Path -Parent $Dest
if ($destDir -and -not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

$out.Save($Dest, $codec, $params)

$g.Dispose(); $out.Dispose(); $src.Dispose()

$kb = [int]((Get-Item $Dest).Length / 1KB)
"{0,5}x{1,-5} {2,5} KB  {3}" -f $Width, $Height, $kb, (Split-Path -Leaf $Dest)
