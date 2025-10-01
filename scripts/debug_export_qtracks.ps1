# Debug script: export compact sample of Get-QAlbumTracks results
$modulePath = 'C:\Users\resto\Documents\PowerShell\Modules\MuFo\MuFo.psm1'
Import-Module $modulePath -Force -ErrorAction Stop

$fixture = Resolve-Path -Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\debug-qobuz-album.html')
$t = Get-QAlbumTracks -HtmlFile $fixture
Write-Host "Parsed tracks: $($t.Count)"
$sample = $t | Select-Object -Property id,Title,DiscNumber,TrackNumber,Artist,@{Name='artists';Expression={ ($_.artists | ForEach-Object { $_.name }) -join '; ' }},duration_ms | Select-Object -First 20
$out = [PSCustomObject]@{ Count = $t.Count; Sample = $sample }
$out | ConvertTo-Json -Depth 6 | Out-File -FilePath (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Private\qtracks_sample.json') -Encoding utf8
Write-Host "WROTE: Private/qtracks_sample.json"
