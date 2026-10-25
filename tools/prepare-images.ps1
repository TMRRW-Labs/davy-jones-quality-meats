# Converts the client's photo library into web-ready JPEGs in assets/img/.
#
#   powershell -ExecutionPolicy Bypass -File tools\prepare-images.ps1
#
# Handles HEIC, PNG, JPG and WEBP through System.Drawing, which reads HEIC on
# this machine because the Windows HEIF extension is installed. Everything is
# resized to the widest size its slot actually needs and saved as JPEG, which
# takes the library from ~144 MB down to something a phone can load.
#
# Source stays untouched. Re-run any time; it overwrites the output.

param(
  [string]$Source = "C:\Users\SamAi\Desktop\Davy Jones Website Images",
  [string]$Dest   = (Join-Path $PSScriptRoot "..\assets\img")
)

Add-Type -AssemblyName System.Drawing

$Dest = [System.IO.Path]::GetFullPath($Dest)
foreach ($sub in @("site", "category", "products")) {
  $null = New-Item -ItemType Directory -Force (Join-Path $Dest $sub)
}

# Target widths per slot. Heroes and banners run full width on a large screen;
# product cards are never wider than about 460 CSS pixels, so 900 covers retina.
$widths = @{ "site" = 1800; "category" = 1600; "products" = 900 }
$quality = 82

$encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
           Where-Object { $_.MimeType -eq "image/jpeg" }
$params = New-Object System.Drawing.Imaging.EncoderParameters 1
$params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
  [System.Drawing.Imaging.Encoder]::Quality, [int]$quality)

function Convert-One {
  param($InFile, $OutFile, $MaxWidth)

  try { $img = New-Object System.Drawing.Bitmap($InFile) }
  catch { Write-Host ("  SKIP (cannot decode) {0}" -f (Split-Path $InFile -Leaf)); return $false }

  try {
    # Honour the EXIF orientation flag before resizing, or phone shots land sideways.
    if ($img.PropertyIdList -contains 274) {
      switch ($img.GetPropertyItem(274).Value[0]) {
        3 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
        6 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
        8 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
      }
    }

    $w = $img.Width; $h = $img.Height
    if ($w -gt $MaxWidth) { $h = [int][math]::Round($h * ($MaxWidth / $w)); $w = $MaxWidth }

    $canvas = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($canvas)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    # Flatten any transparency onto white; the site's photo slots are opaque.
    $g.Clear([System.Drawing.Color]::White)
    $g.DrawImage($img, 0, 0, $w, $h)
    $g.Dispose()

    $canvas.Save($OutFile, $encoder, $params)
    $canvas.Dispose()
    return $true
  }
  finally { $img.Dispose() }
}

$converted = 0; $skipped = 0
$totalIn = 0; $totalOut = 0

foreach ($sub in @("Site", "Category Banners", "Products")) {
  $dir = Join-Path $Source $sub
  if (-not (Test-Path $dir)) { Write-Host "missing source folder: $dir"; continue }

  $outSub = switch ($sub) {
    "Site"             { "site" }
    "Category Banners" { "category" }
    "Products"         { "products" }
  }
  $max = $widths[$outSub]

  Write-Host ""
  Write-Host "$sub -> assets/img/$outSub  (max width $max px)"

  Get-ChildItem $dir -File | Sort-Object Name | ForEach-Object {
    # Lower-case, hyphenated names, so the HTML references stay predictable.
    $base = $_.BaseName.ToLower() -replace "[^a-z0-9]+", "-"
    $base = $base.Trim("-")
    $out = Join-Path (Join-Path $Dest $outSub) ("$base.jpg")

    $totalIn += $_.Length
    if (Convert-One -InFile $_.FullName -OutFile $out -MaxWidth $max) {
      $converted++
      $totalOut += (Get-Item $out).Length
    } else { $skipped++ }
  }
}

Write-Host ""
Write-Host ("{0} converted, {1} skipped" -f $converted, $skipped)
Write-Host ("{0:N1} MB in, {1:N1} MB out" -f ($totalIn/1MB), ($totalOut/1MB))
