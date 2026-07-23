<#
.SYNOPSIS
    Windows read-image — OCR text from images (替代 macOS Vision OCR)
.DESCRIPTION
    Reads text from image files using Tesseract OCR + Windows native APIs.
    Supports: PNG, JPG, BMP, TIFF, clipboard screenshots.
    Output: plain text, JSON with coordinates, or structured analysis.
.PARAMETER Path
    Image file path. If omitted, reads from clipboard.
.PARAMETER Lang
    OCR language (default: chi_sim+eng = Chinese + English)
.PARAMETER Format
    Output format: text | json | analysis
.EXAMPLE
    .\read-image-win.ps1 -Path screenshot.png
    .\read-image-win.ps1 -Path photo.jpg -Lang eng -Format json
    .\read-image-win.ps1 -Format analysis   # from clipboard
#>

[CmdletBinding()]
param(
    [string]$Path = "",
    [string]$Lang = "chi_sim+eng",
    [string]$Format = "text"
)

$Tesseract = "C:\Program Files\Tesseract-OCR\tesseract.exe"
$TempDir   = $env:TEMP

function Get-TextFromImage($imgPath, $lang) {
    $outBase = Join-Path $TempDir "ocr-out"
    & $Tesseract $imgPath $outBase -l $lang 2>&1 | Out-Null
    $txtFile = "$outBase.txt"
    if (Test-Path $txtFile) {
        $text = Get-Content $txtFile -Raw -Encoding UTF8
        Remove-Item $txtFile -Force -ErrorAction SilentlyContinue
        return $text.Trim()
    }
    return ""
}

function Get-TextWithCoords($imgPath, $lang) {
    $outBase = Join-Path $TempDir "ocr-tsv"
    & $Tesseract $imgPath $outBase -l $lang tsv 2>&1 | Out-Null
    $tsvFile = "$outBase.tsv"
    if (-not (Test-Path $tsvFile)) { return @() }
    $lines = Get-Content $tsvFile -Encoding UTF8 | Select-Object -Skip 1
    $results = @()
    foreach ($line in $lines) {
        $cols = $line -split "\t"
        if ($cols.Count -ge 12 -and $cols[11] -ne "") {
            $results += @{
                text   = $cols[11]
                conf   = [int]$cols[10]
                x      = [int]$cols[6]
                y      = [int]$cols[7]
                width  = [int]$cols[8]
                height = [int]$cols[9]
            }
        }
    }
    Remove-Item $tsvFile -Force -ErrorAction SilentlyContinue
    return $results
}

function Get-FromClipboard {
    Add-Type -AssemblyName System.Windows.Forms
    $img = [System.Windows.Forms.Clipboard]::GetImage()
    if (-not $img) { return $null }
    $tmpFile = Join-Path $TempDir "clipboard-ocr.png"
    $img.Save($tmpFile, [System.Drawing.Imaging.ImageFormat]::Png)
    return $tmpFile
}

# Main
$imgPath = if ($Path) { $Path } else { Get-FromClipboard }
if (-not $imgPath -or -not (Test-Path $imgPath)) {
    Write-Host "No image found. Provide -Path or copy image to clipboard." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $Tesseract)) {
    Write-Host "Tesseract not found. Install: winget install UB-Mannheim.TesseractOCR" -ForegroundColor Red
    exit 1
}

switch ($Format) {
    "json" {
        $words = Get-TextWithCoords $imgPath $Lang
        @{
            source = $imgPath
            language = $Lang
            words = $words
            full_text = ($words | ForEach-Object { $_.text }) -join " "
        } | ConvertTo-Json -Depth 3
    }
    "analysis" {
        $text = Get-TextFromImage $imgPath $Lang
        $lines = $text -split "\n" | Where-Object { $_.Trim() -ne "" }
        Write-Host "========== OCR Analysis ==========" -ForegroundColor Cyan
        Write-Host "File: $imgPath" -ForegroundColor Gray
        Write-Host "Chars: $($text.Length) | Lines: $($lines.Count)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "--- Full Text ---" -ForegroundColor Yellow
        Write-Host $text
        Write-Host ""
        Write-Host "--- Line Count ---" -ForegroundColor Yellow
        $lines | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
        if ($lines.Count -gt 20) {
            Write-Host "  ... and $($lines.Count - 20) more lines" -ForegroundColor Gray
        }
    }
    default {
        $text = Get-TextFromImage $imgPath $Lang
        Write-Host $text
    }
}

# Cleanup clipboard temp
if (-not $Path) { Remove-Item $imgPath -Force -ErrorAction SilentlyContinue }
