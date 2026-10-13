param([string]$Source = (Join-Path $PSScriptRoot '../asset/launcher_icon.png'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$image = [System.Drawing.Bitmap]::new((Resolve-Path -LiteralPath $Source).Path)
try {
    if ($image.Width -ne $image.Height) { throw 'Launcher source must be square: do not letterbox a portrait image.' }
    function Resize-Icon([int]$Size) {
        $bitmap = [System.Drawing.Bitmap]::new($Size, $Size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::White)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($image, [System.Drawing.Rectangle]::new(0, 0, $Size, $Size))
        } finally { $graphics.Dispose() }
        return $bitmap
    }
    $densities = [ordered]@{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }
    foreach ($entry in $densities.GetEnumerator()) {
        $bitmap = Resize-Icon $entry.Value
        try {
            $bitmap.Save((Join-Path $root "android/app/src/main/res/mipmap-$($entry.Key)/ic_launcher.png"),
                [System.Drawing.Imaging.ImageFormat]::Png)
        } finally { $bitmap.Dispose() }
    }
    $sizes = @(16, 24, 32, 48, 64, 128, 256)
    $payloads = [System.Collections.Generic.List[byte[]]]::new()
    foreach ($size in $sizes) {
        $bitmap = Resize-Icon $size
        $stream = [IO.MemoryStream]::new()
        try {
            $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
            $payloads.Add($stream.ToArray())
        } finally { $bitmap.Dispose(); $stream.Dispose() }
    }
    $file = [IO.File]::Create((Join-Path $root 'windows/runner/resources/app_icon.ico'))
    $writer = [IO.BinaryWriter]::new($file)
    try {
        $writer.Write([uint16]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]$sizes.Count)
        $offset = 6 + 16 * $sizes.Count
        for ($index = 0; $index -lt $sizes.Count; $index++) {
            $dimension = if ($sizes[$index] -eq 256) { [byte]0 } else { [byte]$sizes[$index] }
            $writer.Write($dimension); $writer.Write($dimension)
            $writer.Write([byte]0); $writer.Write([byte]0)
            $writer.Write([uint16]1); $writer.Write([uint16]32)
            $writer.Write([uint32]$payloads[$index].Length); $writer.Write([uint32]$offset)
            $offset += $payloads[$index].Length
        }
        foreach ($bytes in $payloads) { $writer.Write($bytes, 0, $bytes.Length) }
    } finally { $writer.Dispose(); $file.Dispose() }
    Write-Output 'Generated five Android densities and seven Windows icon sizes from the square source.'
} finally { $image.Dispose() }
