# Basic tag enhancement
Invoke-MuFo -Path "C:\Music" -IncludeTracks -FixTags -FillMissingTitles

# Classical music optimization  
Invoke-MuFo -Path "C:\Classical" -IncludeTracks -FixTags -OptimizeClassicalTags

# Comprehensive validation
Invoke-MuFo -Path "C:\Music" -IncludeTracks -ValidateCompleteness -FixTags -FillMissingTrackNumbersBeforeAll {
    # Import function under test and helpers (mocks will override as needed)
    . "$PSScriptRoot/../Public/Invoke-MuFo.ps1"
    . "$PSScriptRoot/../Private/Connect-Spotify.ps1"
    . "$PSScriptRoot/../Private/Get-SpotifyArtist.ps1"
    . "$PSScriptRoot/../Private/Get-SpotifyArtistAlbums.ps1"
    . "$PSScriptRoot/../Private/Get-SpotifyAlbumMatches.ps1"
    . "$PSScriptRoot/../Private/Get-StringSimilarity.ps1"
}

Describe 'Invoke-MuFo' -Tag 'Unit' {
    Context 'When artist matches by folder name (search path)' {
        BeforeAll {
            $artistPath = Join-Path -Path $TestDrive -ChildPath '10cc'
            New-Item -ItemType Directory -Path $artistPath | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $artistPath '1974 - Sheet Music') | Out-Null

            Mock Connect-SpotifyService { }
            Mock Get-SpotifyArtist {
                @([pscustomobject]@{ Artist = [pscustomobject]@{ Name='10cc'; Id='ART10' }; Score = 1.0 })
            }
            Mock -CommandName Get-SpotifyAlbumMatches -ParameterFilter { $Query -match 'artist:.10cc.' } {
                @([pscustomobject]@{
                    AlbumName   = 'Sheet Music'
                    Score       = 1.0
                    Artists     = @([pscustomobject]@{ Name='10cc'; Id='ART10' })
                    ReleaseDate = '2007-01-01'
                    AlbumType   = 'album'
                    Item        = [pscustomobject]@{ Id = 'ALBUM_ID'; Name = 'Sheet Music'; ReleaseDate = '2007-01-01' }
                })
            }
        }

        It 'emits concise object with proposed new folder name and Decision=rename in Automatic mode' {
            $res = Invoke-MuFo -Path (Join-Path $TestDrive '10cc') -DoIt Automatic -Preview
            $res | Should -Not -BeNullOrEmpty
            $res | Should -HaveCount 1
            $res[0].SpotifyArtist | Should -Be '10cc'
            $res[0].LocalFolder | Should -Be '1974 - Sheet Music'
            $res[0].LocalAlbum | Should -Be 'Sheet Music'
            $res[0].SpotifyAlbum | Should -Be 'Sheet Music'
            $res[0].NewFolderName | Should -Be '2007 - Sheet Music'
            $res[0].Decision | Should -Be 'rename'
            $res[0].ArtistSource | Should -Be 'search'
        }
    }

    Context 'When folder artist is wrong and All-search infers correct artist' {
        BeforeAll {
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
        }

        It 'uses All-search to infer 10cc and proposes the correct rename in Preview' {
            $res = Invoke-MuFo -Path (Join-Path $TestDrive '11cc') -DoIt Smart -Preview
            $res | Should -Not -BeNullOrEmpty
            $res | Should -HaveCount 1
            $res[0].SpotifyArtist | Should -Be '10cc'
            $res[0].ArtistSource | Should -BeIn @('inferred','evaluated')
            $res[0].LocalAlbum | Should -Be 'Sheet Music'
            $res[0].NewFolderName | Should -Be '2007 - Sheet Music'
        }
    }

    Context 'All-search returns decoy first, we still pick best match by scoring' {
        BeforeAll {
            $artistPath = Join-Path -Path $TestDrive -ChildPath '11cc'
            New-Item -ItemType Directory -Path $artistPath | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $artistPath '1974 - Sheet Music') | Out-Null

            Mock Connect-SpotifyService { }
            Mock Get-SpotifyArtist { @([pscustomobject]@{ Artist = [pscustomobject]@{ Name='M11CA'; Id='X1' }; Score = 0.5 }) }
            Mock Get-SpotifyAlbumMatches { @() }
            Mock -CommandName Search-Item -ParameterFilter { $Type -eq 'All' -and $Query -match '11cc\s+Sheet Music' } {
                return @(
                    [pscustomobject]@{
                        Albums = [pscustomobject]@{
                            Items = @(
                                [pscustomobject]@{ Name = 'Sheet Music (Live)'; Artists = @([pscustomobject]@{ Name='Boudewijn Vitar'; Id='BV1' }) },
                                [pscustomobject]@{ Name = 'Sheet Music'; Artists = @([pscustomobject]@{ Name='10cc'; Id='ART10' }) }
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
        }

        It 'chooses 10cc despite a misleading first result' {
            $res = Invoke-MuFo -Path (Join-Path $TestDrive '11cc') -DoIt Smart -Preview
            $res | Should -Not -BeNullOrEmpty
            $res | Should -HaveCount 1
            $res[0].SpotifyArtist | Should -Be '10cc'
            $res[0].NewFolderName | Should -Be '2007 - Sheet Music'
        }
    }

    Context 'When folder artist is wrong but albums imply the correct artist (inference path)' {
        BeforeAll {
            $artistPath = Join-Path -Path $TestDrive -ChildPath '11cc'
            New-Item -ItemType Directory -Path $artistPath | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $artistPath '1974 - Sheet Music') | Out-Null

            # Mocks: weak/irrelevant artist search results
            Mock Connect-SpotifyService { }
            Mock Get-SpotifyArtist {
                # Low-confidence unrelated results
                @(
                    [pscustomobject]@{ Artist = [pscustomobject]@{ Name='M11CA'; Id='X1' }; Score = 0.5 },
                    [pscustomobject]@{ Artist = [pscustomobject]@{ Name='CC116'; Id='X2' }; Score = 0.5 }
                )
            }

            # Mock for the artist inference stage. This will be hit by one of the many inference queries.
            # It returns an album by the *correct* artist ('10cc').
            Mock -CommandName Get-SpotifyAlbumMatches -ParameterFilter { $Query -match 'Sheet Music' -and $Query -notmatch 'artist:"10cc"' } -MockWith {
                param($Query, $AlbumName)
                Write-Verbose "Inference mock triggered for Query: $Query"
                if ($Query -like '*Sheet Music*') {
                    return @(
                        [PSCustomObject]@{
                            AlbumName   = 'Sheet Music'
                            Score       = 1.0
                            Artists     = @([PSCustomObject]@{ Name = '10cc'; Id = 'ART10' })
                            ReleaseDate = '2007-01-01'
                            AlbumType   = 'album'
                            Item        = [pscustomobject]@{ Id = 'ALBUM_ID_INFERENCE'; Name = 'Sheet Music'; ReleaseDate = '2007-01-01' }
                        }
                    )
                }
                return @()
            }

            # Mock for the album validation stage, after '10cc' has been selected.
            # This returns the final, detailed album object.
            Mock -CommandName Get-SpotifyAlbumMatches -ParameterFilter { $Query -match 'artist:"10cc"' } -MockWith {
                Write-Verbose "Validation mock triggered for Query: $($Query)"
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

            # Mock Get-SpotifyArtistAlbums for the 'evaluated' artist selection path.
            # This is called after an artist is inferred to check how well their catalog matches local folders.
            Mock Get-SpotifyArtistAlbums -ParameterFilter { $ArtistId -eq 'ART10' } {
                 @([pscustomobject]@{ Name = 'Sheet Music'; ReleaseDate = '2007-01-01' })
            }
            Mock Get-SpotifyArtistAlbums { @() } # Return empty for any other artist ID

            # Mock Search-Item to return nothing, as this test path relies on Get-SpotifyAlbumMatches for inference.
            # A generic mock is needed to prevent calls from failing, but it should return an empty result.
            Mock Search-Item {
                Write-Verbose "Generic Search-Item mock triggered for Query: $($Query)"
                # This mock needs to return a structure that Get-AlbumItemsFromSearchResult can handle
                # and it must be an array to allow concatenation with other results.
                return @([pscustomobject]@{ Albums = [pscustomobject]@{ Items = @() } })
            } -ParameterFilter { $Type -eq 'All' }
        }

        It 'infers artist from albums in Smart mode and proceeds with validation' {
            $res = Invoke-MuFo -Path (Join-Path $TestDrive '11cc') -DoIt Smart -Preview -Verbose
            $res | Should -Not -BeNullOrEmpty
            $res | Should -HaveCount 1
            $res[0].SpotifyArtist | Should -Be '10cc'
            # The artist source could be 'inferred' from the voting or 'evaluated' from the post-inference catalog check.
            # Both are valid outcomes of a successful inference process.
            $res[0].ArtistSource | Should -BeIn @('inferred', 'evaluated')
            $res[0].NewFolderName | Should -Be '2007 - Sheet Music'
        }
    }

    Context 'Exclusions functionality' {
        BeforeAll {
            $artistPath = Join-Path -Path $TestDrive -ChildPath '10cc'
            New-Item -ItemType Directory -Path $artistPath | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $artistPath '1974 - Sheet Music') | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $artistPath 'Excluded Album') | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $artistPath 'Loaded Exclusion') | Out-Null

            Mock Connect-SpotifyService { }
            Mock Get-SpotifyArtist {
                @([pscustomobject]@{ Artist = [pscustomobject]@{ Name='10cc'; Id='ART10' }; Score = 1.0 })
            }
            # This mock now returns a generic album object for any query within this context.
            # This ensures that when Invoke-MuFo processes folders like 'Excluded Album',
            # it receives a valid object instead of $null, preventing downstream errors.
            # The tests themselves are responsible for verifying the exclusion logic, not the matching logic.
            Mock -CommandName Get-SpotifyAlbumMatches {
                param($Query)
                # Extract album name from a query like 'album:"Sheet Music" artist:"10cc"'
                $albumName = if ($Query -match 'album:"([^"]+)"') { $matches[1] } else { 'Unknown Album' }
                return @([pscustomobject]@{
                    Name        = $albumName
                    AlbumType   = 'album'
                    ReleaseDate = '2007-01-01'
                    Item        = [pscustomobject]@{ Id = "ALBUM_ID_$($albumName -replace '\s','_')" }
                })
            }
        }

        It 'filters out excluded folders from processing' {
            $res = Invoke-MuFo -Path (Join-Path $TestDrive '10cc') -DoIt Automatic -Preview -ExcludeFolders 'Excluded Album', 'Loaded Exclusion'
            $res | Should -Not -BeNullOrEmpty
            $res | Should -HaveCount 1
            $res[0].LocalFolder | Should -Be '1974 - Sheet Music'
            $res[0].NewFolderName | Should -Be '2007 - Sheet Music'
        }

        It 'shows exclusions when -ExcludedFoldersShow is used' {
            $output = Invoke-MuFo -Path (Join-Path $TestDrive '10cc') -DoIt Automatic -Preview -ExcludeFolders 'Excluded Album' -ExcludedFoldersShow 6>&1
            ($output | Out-String) | Should -Match 'Effective Exclusions:'
        }

        It 'loads exclusions from file when -ExcludedFoldersLoad is specified' {
            $exclusionsFile = Join-Path $TestDrive 'exclusions.json'
            @('Loaded Exclusion') | ConvertTo-Json | Set-Content -Path $exclusionsFile

            $res = Invoke-MuFo -Path (Join-Path $TestDrive '10cc') -DoIt Automatic -Preview -ExcludedFoldersLoad $exclusionsFile
            $res | Should -Not -BeNullOrEmpty
            ($res.LocalFolder | Sort-Object) | Should -Be ('1974 - Sheet Music', 'Excluded Album' | Sort-Object)
        }

        It 'merges exclusions when -ExcludedFoldersLoad and -ExcludeFolders are both specified' {
            $exclusionsFile = Join-Path $TestDrive 'exclusions.json'
            @('Loaded Exclusion') | ConvertTo-Json | Set-Content -Path $exclusionsFile

            $res = Invoke-MuFo -Path (Join-Path $TestDrive '10cc') -DoIt Automatic -Preview -ExcludedFoldersLoad $exclusionsFile -ExcludeFolders 'Excluded Album'
            $res | Should -Not -BeNullOrEmpty
            $res | Should -HaveCount 1
            $res[0].LocalFolder | Should -Be '1974 - Sheet Music'
        }

        It 'replaces exclusions when -ExcludedFoldersReplace is specified' {
            $exclusionsFile = Join-Path $TestDrive 'exclusions.json'
            @('Loaded Exclusion') | ConvertTo-Json | Set-Content -Path $exclusionsFile

            # When -ExcludedFoldersReplace is used, the loaded file should be ignored,
            # and only the folders from -ExcludeFolders should be used for exclusion.
            $res = Invoke-MuFo -Path (Join-Path $TestDrive '10cc') -DoIt Automatic -Preview -ExcludedFoldersLoad $exclusionsFile -ExcludeFolders 'Excluded Album' -ExcludedFoldersReplace
            $res | Should -Not -BeNullOrEmpty
            ($res.LocalFolder | Sort-Object) | Should -Be ('1974 - Sheet Music', 'Loaded Exclusion' | Sort-Object)
        }
    }

    Context 'When album has a year prefix, it correctly identifies the album and year' {
        BeforeAll {
            $artistPath = Join-Path -Path $TestDrive -ChildPath 'Arvo Pärt'
            New-Item -ItemType Directory -Path $artistPath | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $artistPath '1984 - Tabula Rasa') | Out-Null

            Mock Connect-SpotifyService { }
            Mock Get-SpotifyArtist {
                @([pscustomobject]@{ Artist = [pscustomobject]@{ Name='Arvo Pärt'; Id='ARTAP' }; Score = 1.0 })
            }
            # Tier 1 (year:1984) returns the correct album
            Mock -CommandName Get-SpotifyAlbumMatches -ParameterFilter { $Query -match 'year:1984' } {
                @([pscustomobject]@{
                    Name        = 'Tabula Rasa'
                    Score       = 1.0
                    Artists     = @([pscustomobject]@{ Name='Arvo Pärt'; Id='ARTAP' })
                    ReleaseDate = '1984-11-01'
                    AlbumType   = 'album'
                    Item        = [pscustomobject]@{ Id = 'ALBUM_ID_1984' }
                })
            }
            # Other tiers return nothing
            Mock -CommandName Get-SpotifyAlbumMatches -ParameterFilter { $Query -notmatch 'year:1984' } { @() }
            Mock Get-SpotifyArtistAlbums { @() }
        }

        It 'selects the 1984 release based on Tier 1 search' {
            $res = Invoke-MuFo -Path (Join-Path $TestDrive 'Arvo Pärt') -DoIt Smart -Preview
            $res | Should -Not -BeNullOrEmpty
            $res | Should -HaveCount 1
            $res[0].SpotifyArtist | Should -Be 'Arvo Pärt'
            $res[0].LocalFolder | Should -Be '1984 - Tabula Rasa'
            $res[0].SpotifyAlbum | Should -Be 'Tabula Rasa'
            $res[0].NewFolderName | Should -Be '1984 - Tabula Rasa'
            $res[0].Decision | Should -Be 'rename'
        }
    }
}
