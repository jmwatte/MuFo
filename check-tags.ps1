# Simple tag checker script
param(
    [Parameter(Mandatory=$true)]
    [string]$Path
)

# Import the module and dot-source the internal function
Import-Module "$PSScriptRoot\MuFo.psd1" -Force
. "$PSScriptRoot\Private\Get-AudioFileTags.ps1"

Write-Host "Checking tags in: $Path" -ForegroundColor Cyan
Write-Host "=" * 50

$files = Get-ChildItem -Path $Path -Recurse -Include *.ape,*.flac,*.mp3,*.m4a,*.ogg,*.wav,*.wma

if ($files.Count -eq 0) {
    Write-Host "No audio files found in $Path" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($files.Count) audio files" -ForegroundColor Green
Write-Host ""

foreach ($file in $files) {
    Write-Host "File: $($file.Name)" -ForegroundColor Yellow
    try {
        $tags = Get-AudioFileTags -Path $file.FullName
        Write-Host "  Title: $($tags.Title)" -ForegroundColor White
        Write-Host "  Artist: $($tags.Artist)" -ForegroundColor White
        Write-Host "  AlbumArtist: $($tags.AlbumArtist)" -ForegroundColor White
        Write-Host "  Track: $($tags.Track)" -ForegroundColor White
        Write-Host "  Genre: $($tags.Genre)" -ForegroundColor White
        Write-Host "  Year: $($tags.Year)" -ForegroundColor White
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}