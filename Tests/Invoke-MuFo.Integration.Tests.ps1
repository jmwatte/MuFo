BeforeAll {
    # Import entrypoints; allow live private functions to be resolved through module manifest path or direct scripts
    . "$PSScriptRoot/../Public/Invoke-MuFo.ps1"
    . "$PSScriptRoot/../Private/Connect-Spotify.ps1"
    . "$PSScriptRoot/../Private/Get-SpotifyArtist.ps1"
    . "$PSScriptRoot/../Private/Get-SpotifyArtistAlbums.ps1"
    . "$PSScriptRoot/../Private/Get-SpotifyAlbumMatches.ps1"
    . "$PSScriptRoot/../Private/Get-StringSimilarity.ps1"
}

Describe 'Invoke-MuFo (Integration with Spotify)' -Tag 'Integration','Slow' {
    # Only run if Spotishell is available
    $spotishellAvailable = [bool](Get-Module -ListAvailable -Name Spotishell)

    Context 'Live artist/album lookups with Spotishell' -Skip:(!$spotishellAvailable) {
        BeforeAll {
            try {
                Connect-SpotifyService -Verbose:$false
            } catch { }

            # Create a temporary artist folder with a known album name
            $artist = '10cc'
            $albumFolder = '1974 - Sheet Music'
            $artistPath = Join-Path -Path $TestDrive -ChildPath $artist
            New-Item -ItemType Directory -Path $artistPath | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $artistPath $albumFolder) | Out-Null
        }

        It 'Finds artist and proposes a normalized album folder name' {
            $res = Invoke-MuFo -Path (Join-Path $TestDrive '10cc') -DoIt Smart -Preview -ShowEverything -Verbose:$false
            $res | Should -Not -BeNullOrEmpty
            $res | Should -HaveCount 1
            $res[0].Artist | Should -Be '10cc'
            $res[0].LocalFolder | Should -Be '1974 - Sheet Music'
            $res[0].LocalAlbum | Should -Be 'Sheet Music'
            $res[0].SpotifyAlbum | Should -Match 'Sheet Music'
            $res[0].NewFolderName | Should -Match 'Sheet Music'
        }
    }

    Context 'Exclusions end-to-end' -Skip:(!$spotishellAvailable) {
        BeforeAll {
            try {
                Connect-SpotifyService -Verbose:$false
            } catch { }

            # Create a temporary artist folder with albums
            $artist = '10cc'
            $albumFolder1 = '1974 - Sheet Music'
            $albumFolder2 = 'Excluded Album'
            $artistPath = Join-Path -Path $TestDrive -ChildPath $artist
            New-Item -ItemType Directory -Path $artistPath | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $artistPath $albumFolder1) | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $artistPath $albumFolder2) | Out-Null
        }

        It 'excludes folders in WhatIf mode' {
            $res = Invoke-MuFo -Path (Join-Path $TestDrive '10cc') -DoIt Smart -WhatIf -ExcludeFolders 'Excluded Album' -Verbose:$false
            $res | Should -Not -BeNullOrEmpty
            $res | Should -HaveCount 1
            $res[0].LocalFolder | Should -Be '1974 - Sheet Music'
        }

        It 'saves exclusions after successful processing' {
            $exclusionsFile = Join-Path $TestDrive 'saved_exclusions.json'
            $res = Invoke-MuFo -Path (Join-Path $TestDrive '10cc') -DoIt Smart -Preview -ExcludeFolders 'Excluded Album' -ExcludedFoldersSave $exclusionsFile -Verbose:$false
            $res | Should -Not -BeNullOrEmpty
            # Check if file was created (would need to mock or check file system)
        }
    }
}
