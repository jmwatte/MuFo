function Save-TagsForFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][hashtable]$TagValues,
        [Parameter()][switch]$WhatIf
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "File does not exist: $FilePath"
    }

    $locked = Test-FileLocked -Path $FilePath
    if ($locked) {
        $result = Wait-ForFileUnlock -Path $FilePath
        if ($result.Action -eq 'skip') {
            Write-Warning "Skipping file: $FilePath"
            return @{ Success = $false; Reason = 'skipped' }
        }
        elseif ($result.Action -eq 'force') {
            Write-Warning "Attempting forced write on file: $FilePath"
            # continue to attempt save
        }
        # else proceed because user freed the file
    }

    try {
        if ($WhatIf.IsPresent -or $WhatIf) {
            Write-Host "WhatIf: would open and save tags to $FilePath"
            return @{ Success = $true; WhatIf = $true }
        }

        # Open TagLib.File, set tags, save, dispose
        $tagFile = [TagLib.File]::Create($FilePath)
        try {
            foreach ($k in $TagValues.Keys) {
                $v = $TagValues[$k]
                switch ($k) {
                    'Title' { $tagFile.Tag.Title = $v }
                    'Track' { $tagFile.Tag.Track = [uint]$v }
                    'Disc' { $tagFile.Tag.Disc = [uint]$v }
                    'Performers' { $tagFile.Tag.Performers = @($v) }
                    'Genres' { $tagFile.Tag.Genres = ($tagFile.Tag.Genres + @($v)) | Select-Object -Unique }
                    default {
                        if ($tagFile.Tag.PSObject.Properties.Match($k)) {
                            $tagFile.Tag.$k = $v
                        }
                    }
                }
            }
            $tagFile.Save()
        }
        finally {
            $tagFile.Dispose()
        }

        return @{ Success = $true }
    }
    catch {
        Write-Warning "Failed to save tags for $($FilePath): $_"
        return @{ Success = $false; Reason = $_.Exception.Message }
    }
}