Get-ChildItem -Path "$PSScriptRoot\..\Public" -Filter '*.ps1' | ForEach-Object {
    $path = $_.FullName
    Write-Output "SOURCING: $($_.Name)"
    try {
        . $path
        Write-Output "-> OK"
    } catch {
        Write-Output "-> ERROR: $path : $($_.Exception.Message)"
    }
}
