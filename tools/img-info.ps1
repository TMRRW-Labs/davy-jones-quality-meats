# Prints "WIDTHxHEIGHT path" for each image given. System.Drawing reads the
# Sony-Exif JPEGs that WPF rejects, which is why it is used here.
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Paths)
Add-Type -AssemblyName System.Drawing
foreach ($p in $Paths) {
  try {
    $i = [System.Drawing.Image]::FromFile((Resolve-Path $p))
    "{0,5}x{1,-5} {2}" -f $i.Width, $i.Height, $p
    $i.Dispose()
  } catch { "  ERROR  $p : $($_.Exception.Message)" }
}
