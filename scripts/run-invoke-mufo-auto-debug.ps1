try {
    Import-Module 'c:\Users\resto\Documents\PowerShell\Modules\MuFo\MuFo.psm1' -Force -ErrorAction Stop
    Invoke-MuFoManual -Path 'E:\_CorrectedMusic\Alexander Rudin' -Provider 'Qobuz' -WhatIf -AutoSelect
} catch {
    Write-Host 'EXCEPTION: '
    Write-Host $_.Exception.Message
    Write-Host 'TYPE:'
    Write-Host $_.Exception.GetType().FullName
    Write-Host 'STACK:'
    Write-Host $_.ScriptStackTrace
    Write-Host 'FULL:'
    $_.Exception | Format-List * -Force
    exit 1
}
