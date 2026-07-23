<#
.SYNOPSIS
    Windows download-helper — equivalent to download-anything/smmart skills
.DESCRIPTION
    Unified download tool wrapping yt-dlp + FFmpeg.
    Supports: video, audio, playlist, thumbnail, subtitle extraction.
    All downloads go to ~/Downloads/<category>/ by default.
.PARAMETER Url
    URL to download
.PARAMETER Type
    video | audio | playlist | thumbnail | info
.PARAMETER Output
    Output directory (default: ~/Downloads/<type>/)
.EXAMPLE
    .\download-helper.ps1 -Url "https://youtube.com/watch?v=..." -Type audio
    .\download-helper.ps1 -Url "https://youtube.com/playlist?list=..." -Type playlist
    .\download-helper.ps1 -Url "https://..." -Type info
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Url,
    [ValidateSet("video","audio","playlist","thumbnail","info")]
    [string]$Type = "video",
    [string]$Output = ""
)

$ytdlp  = "yt-dlp"
$ffmpeg = "ffmpeg"

# Verify tools
if (-not (Get-Command $ytdlp -ErrorAction SilentlyContinue)) {
    Write-Host "yt-dlp not found. Install: winget install yt-dlp.yt-dlp" -ForegroundColor Red
    exit 1
}

$baseDir = if ($Output) { $Output } else { "$env:USERPROFILE\Downloads\$Type" }
New-Item -ItemType Directory -Path $baseDir -Force | Out-Null

$commonArgs = @(
    "--no-playlist",
    "--no-mtime",
    "--embed-metadata",
    "--no-overwrites"
)

switch ($Type) {
    "video" {
        Write-Host "Downloading video..." -ForegroundColor Cyan
        & $ytdlp $Url @commonArgs `
            -f "bestvideo[ext<=mp4]+bestaudio[ext<=m4a]/best[ext<=mp4]/best" `
            --merge-output-format mp4 `
            -o "$baseDir\%(title)s.%(ext)s"
    }
    "audio" {
        Write-Host "Downloading audio..." -ForegroundColor Cyan
        & $ytdlp $Url @commonArgs `
            -f "bestaudio" `
            --extract-audio --audio-format mp3 --audio-quality 0 `
            -o "$baseDir\%(title)s.%(ext)s"
    }
    "playlist" {
        Write-Host "Downloading playlist..." -ForegroundColor Cyan
        & $ytdlp $Url `
            --yes-playlist `
            --embed-metadata `
            -f "bestvideo[ext<=mp4]+bestaudio[ext<=m4a]/best[ext<=mp4]/best" `
            --merge-output-format mp4 `
            -o "$baseDir\%(playlist_index)s-%(title)s.%(ext)s"
    }
    "thumbnail" {
        Write-Host "Downloading thumbnail..." -ForegroundColor Cyan
        & $ytdlp $Url --skip-download --write-thumbnail -o "$baseDir\%(title)s"
    }
    "info" {
        Write-Host "Fetching info..." -ForegroundColor Cyan
        & $ytdlp $Url --dump-json | ConvertFrom-Json | Select-Object title,duration,view_count,like_count,upload_date,description | Format-List
    }
}

Write-Host "Done! -> $baseDir" -ForegroundColor Green
