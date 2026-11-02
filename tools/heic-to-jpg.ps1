# Convert a HEIC to JPEG at full resolution.
#
# System.Drawing has no HEIF decoder. WPF gets one from the HEIF Image
# Extension that ships with most Windows 10/11 installs, so this goes through
# WPF and falls over with a clear message if the extension is absent.
param(
  [Parameter(Mandatory = $true)][string]$Source,
  [Parameter(Mandatory = $true)][string]$Dest,
  [int]$Quality = 92
)
Add-Type -AssemblyName PresentationCore, WindowsBase

$uri = New-Object System.Uri((Resolve-Path $Source))
try {
  $dec = [System.Windows.Media.Imaging.BitmapDecoder]::Create(
    $uri,
    [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,
    [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
} catch {
  throw "Could not decode $Source. Install the HEIF Image Extension from the Microsoft Store. ($($_.Exception.Message))"
}

$frame = $dec.Frames[0]
$enc = New-Object System.Windows.Media.Imaging.JpegBitmapEncoder
$enc.QualityLevel = $Quality
$enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($frame))

$fs = [System.IO.File]::Create((Join-Path (Get-Location) $Dest))
$enc.Save($fs)
$fs.Close()

"{0}x{1}  {2}" -f $frame.PixelWidth, $frame.PixelHeight, $Dest
