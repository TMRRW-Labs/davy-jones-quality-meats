# Minimal static file server for previewing dist/ — no toolchain required.
#   powershell -ExecutionPolicy Bypass -File serve.ps1 [-Port 8181]
param([int]$Port = 8181, [string]$Root = "dist")

$root = (Resolve-Path (Join-Path $PSScriptRoot $Root)).Path
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $root at http://localhost:$Port/  (Ctrl+C to stop)"

$types = @{
  ".html" = "text/html; charset=utf-8"; ".css" = "text/css; charset=utf-8"
  ".js" = "application/javascript; charset=utf-8"; ".svg" = "image/svg+xml"
  ".webp" = "image/webp"; ".png" = "image/png"; ".jpg" = "image/jpeg"
  ".xml" = "application/xml"; ".txt" = "text/plain; charset=utf-8"
}

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $rel = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
    if ($rel -eq "") { $rel = "index.html" }
    $path = Join-Path $root $rel
    if (Test-Path $path -PathType Container) { $path = Join-Path $path "index.html" }
    if (-not (Test-Path $path -PathType Leaf)) { $path = "$path.html" }

    if (Test-Path $path -PathType Leaf) {
      $ext = [System.IO.Path]::GetExtension($path).ToLower()
      $ctx.Response.ContentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { "application/octet-stream" }
      $bytes = [System.IO.File]::ReadAllBytes($path)
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $ctx.Response.StatusCode = 404
      $msg = [System.Text.Encoding]::UTF8.GetBytes("404 - $rel")
      $ctx.Response.OutputStream.Write($msg, 0, $msg.Length)
    }
    $ctx.Response.OutputStream.Close()
  }
} finally { $listener.Stop() }
