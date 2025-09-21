# Quick debug test to see what the failing tests are getting

Describe 'Debug Test Results' {
    BeforeAll {
        # Import function under test and helpers 
        . "$PSScriptRoot/Public/Invoke-MuFo.ps1"
        . "$PSScriptRoot/Private/Connect-Spotify.ps1"
        . "$PSScriptRoot/Private/Get-SpotifyArtist.ps1"
        . "$PSScriptRoot/Private/Get-SpotifyArtistAlbums.ps1"
        . "$PSScriptRoot/Private/Get-SpotifyAlbumMatches.ps1"
        . "$PSScriptRoot/Private/Get-StringSimilarity.ps1"
        
        $artistPath = Join-Path -Path $TestDrive -ChildPath '11cc'
        New-Item -ItemType Directory -Path $artistPath | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $artistPath '1974 - Sheet Music') | Out-Null

        Mock Connect-SpotifyService { }
        Mock Get-SpotifyArtist {
            @([pscustomobject]@{ Artist = [pscustomobject]@{ Name='M11CA'; Id='X1' }; Score = 0.5 })
        }
        Mock -CommandName Get-SpotifyAlbumMatches { @() }
        Mock -CommandName Search-Item -ParameterFilter { $Type -eq 'All' -and $Query -match '11cc\s+Sheet Music' } {
            return @(
                [pscustomobject]@{
                    Albums = [pscustomobject]@{
                        Items = @(
                            [pscustomobject]@{
                                Name    = 'Sheet Music'
                                Artists = @([pscustomobject]@{ Name='10cc'; Id='ART10' })
                            }
                        )
                    }
                }
            )
        }
        Mock Get-SpotifyArtistAlbums {
            @([pscustomobject]@{
                Name        = 'Sheet Music'
                AlbumType   = 'album'
                ReleaseDate = '2007-01-01'
                Item        = [pscustomobject]@{ Id = 'ALBUM_ID' }
            })
        }
        
        # Enhanced mock for album validation
        Mock -CommandName Get-SpotifyAlbumMatches -ParameterFilter { $Query -match 'artist:"10cc"' } -MockWith {
            @(
                [pscustomobject]@{
                    AlbumName   = 'Sheet Music'
                    Score       = 1.0
                    Artists     = @([pscustomobject]@{ Name='10cc'; Id='ART10' })
                    ReleaseDate = '2007-01-01'
                    AlbumType   = 'album'
                    Item        = [pscustomobject]@{ Id = 'ALBUM_ID_VALIDATED'; Name = 'Sheet Music'; ReleaseDate = '2007-01-01' }
                }
            )
        }
    }

    It 'debug what we get' {
        $res = Invoke-MuFo -Path (Join-Path $TestDrive '11cc') -DoIt Smart -Preview
        
        Write-Host "Result count: $($res.Count)" -ForegroundColor Yellow
        if ($res.Count -gt 0) {
            Write-Host "Result properties:" -ForegroundColor Yellow
            $res[0] | Get-Member | Write-Host
            Write-Host "Result values:" -ForegroundColor Yellow
            $res[0] | ConvertTo-Json -Depth 3 | Write-Host
        }
        
        $res | Should -Not -BeNullOrEmpty
    }
}