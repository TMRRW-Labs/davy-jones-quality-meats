# Fit a square-ish photo into a wide hero without cropping the subject.
#
# The page heroes are full-bleed and roughly 2.7:1, so object-fit:cover throws
# away well over half the height of a near-square source: the dry aged prime
# rib came out as an unreadable slab of meat. This builds a wide canvas
# instead. A blurred, over-scaled copy of the same photo fills the frame and
# the sharp photo sits on top at close to full height, its edges feathered
# into the blur so the join reads as depth of field rather than a pasted
# rectangle. Both layers come from one image, so the colours already agree.
#
# -OffsetX shifts the sharp layer across the leftover width, keeping the
# subject clear of the headline: 0.5 centres it, 1.0 pins it right.
param(
  [Parameter(Mandatory = $true)][string]$Source,
  [Parameter(Mandatory = $true)][string]$Dest,
  [int]$Width      = 2400,
  [int]$Height     = 1000,
  [double]$Scale   = 0.94,   # sharp layer height, as a fraction of the canvas
  [double]$OffsetX = 0.74,
  [int]$Feather    = 90,     # px over which the sharp layer fades out
  [int]$Blur       = 26,     # px width the blur layer is squashed to
  [double]$Dim     = 0.80,   # how far the blurred layer is knocked back
  [int]$Quality    = 88
)

Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Image]::FromFile((Resolve-Path $Source))
if ($src.PropertyIdList -contains 0x0112) {
  switch ($src.GetPropertyItem(0x0112).Value[0]) {
    3 { $src.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
    6 { $src.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
    8 { $src.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
  }
}

function New-Canvas([int]$w, [int]$h) {
  $b = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($b)
  $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  return @($b, $g)
}

# Blur by squashing to a few dozen pixels and letting bicubic smooth it on the
# way back up. Cheap, and indistinguishable from a real blur at this radius.
$tinyH = [Math]::Max(1, [int]($Blur * $Height / $Width))
$tiny, $tg = New-Canvas $Blur $tinyH
$tg.DrawImage($src, 0, 0, $Blur, $tinyH)
$tg.Dispose()

$out, $g = New-Canvas $Width $Height
$g.DrawImage($tiny, 0, 0, $Width, $Height)

$brush = New-Object System.Drawing.SolidBrush(
  [System.Drawing.Color]::FromArgb([int](255 * (1 - $Dim)), 10, 9, 8))
$g.FillRectangle($brush, 0, 0, $Width, $Height)
$brush.Dispose()

# The sharp layer, drawn into its own bitmap so its alpha can be feathered.
$sharpH = [int]($Height * $Scale)
$sharpW = [int]($sharpH * $src.Width / $src.Height)
$sharp, $sg = New-Canvas $sharpW $sharpH
$sg.DrawImage($src, 0, 0, $sharpW, $sharpH)
$sg.Dispose()

# Ramp alpha down over the outer $Feather pixels. Done on the raw buffer: a
# per-pixel GetPixel loop over two million pixels takes minutes in PowerShell.
if ($Feather -gt 0) {
  $rect = New-Object System.Drawing.Rectangle(0, 0, $sharpW, $sharpH)
  $data = $sharp.LockBits($rect,
    [System.Drawing.Imaging.ImageLockMode]::ReadWrite,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $bytes = New-Object byte[] ($data.Stride * $sharpH)
  [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)

  # Precompute the horizontal ramp once; every row reuses it.
  $colF = New-Object double[] $sharpW
  for ($x = 0; $x -lt $sharpW; $x++) {
    $d = [Math]::Min($x, $sharpW - 1 - $x)
    $colF[$x] = if ($d -ge $Feather) { 1.0 } else { $d / $Feather }
  }

  for ($y = 0; $y -lt $sharpH; $y++) {
    $dy = [Math]::Min($y, $sharpH - 1 - $y)
    $rowF = if ($dy -ge $Feather) { 1.0 } else { $dy / $Feather }
    $row = $y * $data.Stride
    for ($x = 0; $x -lt $sharpW; $x++) {
      $f = $rowF * $colF[$x]
      if ($f -lt 1.0) {
        # Smoothstep, so the fade has no visible start or end.
        $f = $f * $f * (3.0 - 2.0 * $f)
        $i = $row + $x * 4 + 3
        $bytes[$i] = [byte]([Math]::Round($bytes[$i] * $f))
      }
    }
  }

  [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $bytes.Length)
  $sharp.UnlockBits($data)
}

$g.DrawImage($sharp, [int](($Width - $sharpW) * $OffsetX), [int](($Height - $sharpH) / 2), $sharpW, $sharpH)

$codec  = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
          Where-Object { $_.MimeType -eq 'image/jpeg' }
$params = New-Object System.Drawing.Imaging.EncoderParameters(1)
$params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
  [System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)
$out.Save($Dest, $codec, $params)

$g.Dispose(); $out.Dispose(); $tiny.Dispose(); $sharp.Dispose(); $src.Dispose()
"{0}x{1}  {2} KB  {3}" -f $Width, $Height, [int]((Get-Item $Dest).Length / 1KB), (Split-Path -Leaf $Dest)
