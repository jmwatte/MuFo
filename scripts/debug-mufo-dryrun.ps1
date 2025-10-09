Import-Module 'c:\Users\resto\Documents\PowerShell\Modules\MuFo\MuFo.psm1' -Force
try {
    Invoke-MuFoManual -Path 'E:\_CorrectedMusic\Alexander Rudin' -Provider 'Qobuz' -goA -goB -goC -WhatIf -Verbose -ErrorAction Stop
}
catch {
    Write-Host '---- ERROR Exception.Message ----'
    Write-Host $_.Exception.Message
    Write-Host '---- ERROR ToString ----'
    Write-Host ($_ | Out-String)
    Write-Host '---- SCRIPT STACK TRACE ----'
    Write-Host $_.ScriptStackTrace
}
Write-Host 'Debug script finished.'
