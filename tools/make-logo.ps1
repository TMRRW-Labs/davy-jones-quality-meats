# Prepares the Davy Jones logo for the site's dark header and footer.
#
#   powershell -ExecutionPolicy Bypass -File tools\make-logo.ps1
#
# The supplied artwork fills its dark areas with #040000, a near-black that is
# not quite the site's --ink (#0C0B0A). Against the header that difference
# reads as a faint black slab behind the wordmark. This remaps every dark
# pixel to --ink so the fill disappears into the background, leaving the red
# script, the white keyline and the butcher doing the work.
#
# Alpha matters: Windows' WebP decoder flattens the alpha channel onto white
# unless the frame is read with PreservePixelFormat, which is why that option
# is not optional here.

param(
  [string]$Source = "$PSScriptRoot\..\assets\img\src\dj-logo-source.webp",
  [string]$Dest   = "$PSScriptRoot\..\assets\img\dj-logo.png",
  [int]$Width     = 720,
  [string]$Ink    = "0C0B0A",
  [int]$DarkMax   = 60        # a pixel counts as "dark" if max(r,g,b) <= this
)

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$Source = [System.IO.Path]::GetFullPath($Source)
$Dest   = [System.IO.Path]::GetFullPath($Dest)

$inkR = [Convert]::ToInt32($Ink.Substring(0,2),16)
$inkG = [Convert]::ToInt32($Ink.Substring(2,2),16)
$inkB = [Convert]::ToInt32($Ink.Substring(4,2),16)

# ---- decode, keeping the alpha channel -------------------------------------
$dec  = [System.Windows.Media.Imaging.BitmapDecoder]::Create(
          (New-Object System.Uri($Source)), 'PreservePixelFormat', 'OnLoad')
$conv = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap(
          $dec.Frames[0], [System.Windows.Media.PixelFormats]::Bgra32, $null, 0)

$w = $conv.PixelWidth; $h = $conv.PixelHeight; $stride = $w * 4
$buf = New-Object byte[] ($stride * $h)
$conv.CopyPixels($buf, $stride, 0)

# ---- remap the dark fill ----------------------------------------------------
$changed = 0
for ($i = 0; $i -lt $buf.Length; $i += 4) {
  if ($buf[$i+3] -eq 0) { continue }                 # fully transparent
  $b = $buf[$i]; $g = $buf[$i+1]; $r = $buf[$i+2]
  $mx = [Math]::Max($r, [Math]::Max($g, $b))
  if ($mx -le $DarkMax) {
    $buf[$i] = $inkB; $buf[$i+1] = $inkG; $buf[$i+2] = $inkR
    $changed++
  }
}

$fixed = [System.Windows.Media.Imaging.BitmapSource]::Create(
           $w, $h, 96, 96, [System.Windows.Media.PixelFormats]::Bgra32, $null, $buf, $stride)

# ---- resize -----------------------------------------------------------------
$scale  = $Width / $w
$target = New-Object System.Windows.Media.Imaging.TransformedBitmap(
            $fixed, (New-Object System.Windows.Media.ScaleTransform($scale, $scale)))

# RenderTargetBitmap with HighQuality gives a cleaner downscale than the
# default for artwork with hard edges like this.
$dv = New-Object System.Windows.Media.DrawingVisual
$ctx = $dv.RenderOpen()
$rect = New-Object System.Windows.Rect 0, 0, $target.PixelWidth, $target.PixelHeight
[System.Windows.Media.RenderOptions]::SetBitmapScalingMode($dv, 'HighQuality')
$ctx.DrawImage($fixed, $rect)
$ctx.Close()
$rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(
         $target.PixelWidth, $target.PixelHeight, 96, 96,
         [System.Windows.Media.PixelFormats]::Pbgra32)
$rtb.Render($dv)

$null = New-Item -ItemType Directory -Force (Split-Path $Dest)
$enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
$enc.Interlace = 'Off'
$enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
$fs = [System.IO.File]::Create($Dest); $enc.Save($fs); $fs.Close()

$kb = [Math]::Round((Get-Item $Dest).Length / 1KB, 1)
"Source      : {0}x{1}" -f $w, $h
"Remapped    : {0} dark pixels -> #{1}" -f $changed, $Ink
"Written     : {0}  ({1}x{2}, {3} KB)" -f $Dest, $rtb.PixelWidth, $rtb.PixelHeight, $kb
