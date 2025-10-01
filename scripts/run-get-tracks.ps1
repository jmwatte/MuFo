Import-Module "$PSScriptRoot\..\MuFo.psm1" -Force

try {
    $res = Get-TracksFromHtml
} catch {
    Write-Error "Get-TracksFromHtml failed: $_"
    exit 1
}

Write-Output "Count=$($res.Count)"
if ($res.Count -gt 0) {
    $res | Select-Object id,name,disc_number,track_number | Format-Table -AutoSize
    $jsonPath = Join-Path -Path $PSScriptRoot -ChildPath 'get-tracks-output.json'
    $res | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Output "Wrote JSON to $jsonPath"
} else {
    Write-Output 'No results'
}
# Runner to execute Get-TracksFromHtml and show results
Set-StrictMode -Version Latest
Set-Location -Path "${PSScriptRoot}\..\Private"

. "${PSScriptRoot}\..\Public\Get-TracksFromHtml.ps1"

$json = Get-TracksFromHtml
if (-not $json) {
    Write-Output "NO OUTPUT from Get-TracksFromHtml"
    exit 0
}

try {
    $objs = $json | ConvertFrom-Json
}
catch {
    Write-Error "Failed to ConvertFrom-Json: $_"
    exit 1
}

$objs | Select-Object id,name,disc_number,track_number | Format-Table -AutoSize

# also write to file for inspection
$OutPath = Join-Path -Path "${PSScriptRoot}" -ChildPath "get-tracks-output.json"
$objs | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutPath -Encoding utf8
Write-Output "WROTE: $OutPath"
