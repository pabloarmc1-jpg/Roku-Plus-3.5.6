[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$PlaylistUrl,

    [string]$OutputDirectory = (Join-Path $PSScriptRoot "clean-hls"),

    [string]$FfmpegPath = "ffmpeg",

    [string]$UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/126.0 Safari/537.36",

    [string]$Referer = ""
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host ("[CleanHLS] " + $Message)
}

if (-not (Get-Command $FfmpegPath -ErrorAction SilentlyContinue)) {
    throw "No encuentro FFmpeg. Instálalo y asegúrate de que ffmpeg.exe esté en PATH, o usa -FfmpegPath con su ruta completa."
}

if ($PlaylistUrl -notmatch '^https?://') {
    throw "PlaylistUrl debe ser una URL HTTP/HTTPS de la playlist multimedia .m3u8 (no la master)."
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$tempDirectory = Join-Path $OutputDirectory "_source"
New-Item -ItemType Directory -Force -Path $tempDirectory | Out-Null

$headers = @{ "User-Agent" = $UserAgent }
if (-not [string]::IsNullOrWhiteSpace($Referer)) {
    $headers["Referer"] = $Referer
}

$playlistPath = Join-Path $tempDirectory "source.m3u8"
Write-Step "Descargando playlist de origen..."
Invoke-WebRequest -Uri $PlaylistUrl -Headers $headers -OutFile $playlistPath -TimeoutSec 120 -UseBasicParsing
$lines = @(Get-Content -LiteralPath $playlistPath)
if ($lines.Count -lt 3 -or $lines[0].Trim() -ne "#EXTM3U") {
    throw "La URL no devolvió una playlist HLS válida."
}
if ($lines | Where-Object { $_ -match '^#EXT-X-(KEY|MAP):' }) {
    throw "La playlist contiene cifrado EXT-X-KEY o inicialización EXT-X-MAP; esta prueba solo admite MPEG-TS HLS sin cifrar."
}
if ($lines | Where-Object { $_ -match '^#EXT-X-STREAM-INF:' }) {
    throw "Se recibió una master playlist. Usa la URL de la variante multimedia seleccionada (por ejemplo, la de 480p), no la master."
}

$segmentLines = @()
foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -gt 0 -and -not $trimmed.StartsWith("#")) {
        $segmentLines += $line
    }
}
if ($segmentLines.Count -eq 0) {
    throw "No se encontraron segmentos en la playlist."
}

Write-Step ("Encontrados " + $segmentLines.Count + " segmentos. Se remuxearán sin el PID de metadatos ID3.")
$rewritten = New-Object System.Collections.Generic.List[string]
$segmentIndex = 0

foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
        $rewritten.Add($line)
        continue
    }

    $segmentIndex++
    $sourceUri = [System.Uri]::new([System.Uri]$PlaylistUrl, $trimmed)
    $inputFile = Join-Path $tempDirectory ("source-{0:D5}.ts" -f $segmentIndex)
    $outputFile = Join-Path $OutputDirectory ("clean-{0:D5}.ts" -f $segmentIndex)
    $outputName = "clean-{0:D5}.ts" -f $segmentIndex

    Write-Step ("Segmento " + $segmentIndex + "/" + $segmentLines.Count + ": descarga")
    Invoke-WebRequest -Uri $sourceUri.AbsoluteUri -Headers $headers -OutFile $inputFile -TimeoutSec 180 -UseBasicParsing

    Write-Step ("Segmento " + $segmentIndex + "/" + $segmentLines.Count + ": remux H.264/AAC y exclusión de ID3")
    & $FfmpegPath -hide_banner -loglevel error -y -copyts -i $inputFile -map 0:v:0 -map "0:a:0?" -c copy -mpegts_copyts 1 -muxdelay 0 -muxpreload 0 -mpegts_flags +resend_headers -avoid_negative_ts disabled -f mpegts $outputFile
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputFile) -or (Get-Item -LiteralPath $outputFile).Length -lt 188) {
        throw "FFmpeg no pudo remuxear el segmento $segmentIndex. Se detuvo sin generar una playlist final."
    }

    Remove-Item -LiteralPath $inputFile -Force
    $rewritten.Add($outputName)
}

$manifestPath = Join-Path $OutputDirectory "index-clean.m3u8"
$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($manifestPath, $rewritten, $encoding)

Write-Host ""
Write-Step ("LISTO: " + $manifestPath)
Write-Step ("Segmentos preparados: " + $segmentIndex)
Write-Step "Ahora abre PowerShell en la carpeta que contiene la carpeta clean-hls y ejecuta:"
Write-Host "  py -m http.server 8000 --bind 0.0.0.0"
Write-Step "Desde el Roku, la URL será:"
Write-Host "  http://IP_DE_TU_PC:8000/clean-hls/index-clean.m3u8"
Write-Step "No cierres la ventana del servidor mientras haces la prueba."
