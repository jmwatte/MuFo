BeforeAll {
    # Import function under test and all helpers (mocks will override as needed)
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
            # Folder structure in TestDrive:
            $artistPath = Join-Path -Path $TestDrive -ChildPath '10cc'
            New-Item -ItemType Directory -Path $artistPath | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $artistPath '1974 - Sheet Music') | Out-Null

            # Mocks
            Mock Connect-SpotifyService { }
            Mock Get-SpotifyArtist {
                # Return a confident match for folder artist
                @([pscustomobject]@{ Artist = [pscustomobject]@{ Name='10cc'; Id='ART10' }; Score = 1.0 })
            }
            Mock Get-SpotifyArtistAlbums {
                # Return Spotify album with normalized name and release year 2007
                @([pscustomobject]@{ Name = 'Sheet Music'; AlbumType='album'; ReleaseDate='2007-01-01' })
            }
        }

        It 'emits concise object with proposed new folder name and Decision=rename in Automatic mode' {
            $res = Invoke-MuFo -Path (Join-Path $TestDrive '10cc') -DoIt Automatic -Preview
            $res | Should -Not -BeNullOrEmpty
            $res | Should -HaveCount 1
            $res[0].Artist | Should -Be '10cc'
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

            # Mocks
            Mock Connect-SpotifyService { }
            # Artist search returns irrelevant candidates
            Mock Get-SpotifyArtist {
                @(
                    [pscustomobject]@{ Artist = [pscustomobject]@{ Name='M11CA'; Id='X1' }; Score = 0.8 },
                    [pscustomobject]@{ Artist = [pscustomobject]@{ Name='CC116'; Id='X2' }; Score = 0.8 }
                )
            }
            # Album-only helper returns empty to force All-query fallback
            Mock Get-SpotifyAlbumMatches { @() }
            # Intercept Search-Item -Type All and return an object with Albums.Items matching 'Sheet Music' by 10cc
            Mock -CommandName Search-Item -ParameterFilter { $Type -eq 'All' -and $Query -match '11cc\s+Sheet Music' } {
                [pscustomobject]@{
                    Albums = [pscustomobject]@{
                        Items = @(
                            [pscustomobject]@{
                                Name = 'Sheet Music'
                                Artists = @([pscustomobject]@{ Name='10cc'; Id='ART10' })
                            }
                        )
                    }
                }
            }
            Mock Get-SpotifyArtistAlbums { @([pscustomobject]@{ Name = 'Sheet Music'; AlbumType='album'; ReleaseDate='2007-01-01' }) }
        }

        It 'uses All-search to infer 10cc and proposes the correct rename in Preview' {
            $res = Invoke-MuFo -Path (Join-Path $TestDrive '11cc') -DoIt Smart -Preview
            $res | Should -Not -BeNullOrEmpty
            $res | Should -HaveCount 1
            $res[0].Artist | Should -Be '10cc'
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
            Mock Get-SpotifyArtist { @([pscustomobject]@{ Artist = [pscustomobject]@{ Name='M11CA'; Id='X1' }; Score = 0.7 }) }
            Mock Get-SpotifyAlbumMatches { @() }
            # All-search returns a wrong first album then the correct 'Sheet Music' by 10cc
            Mock -CommandName Search-Item -ParameterFilter { $Type -eq 'All' -and $Query -match '11cc\s+Sheet Music' } {
                [pscustomobject]@{
                    Albums = [pscustomobject]@{
                        Items = @(
                            [pscustomobject]@{ Name = 'Sheet Music (Live)'; Artists = @([pscustomobject]@{ Name='Boudewijn Vitar'; Id='BV1' }) },
                            [pscustomobject]@{ Name = 'Sheet Music'; Artists = @([pscustomobject]@{ Name='10cc'; Id='ART10' }) }
                        )
                    }
                }
            }
            Mock Get-SpotifyArtistAlbums { @([pscustomobject]@{ Name = 'Sheet Music'; AlbumType='album'; ReleaseDate='2007-01-01' }) }
        }

        It 'chooses 10cc despite a misleading first result' {
            $res = Invoke-MuFo -Path (Join-Path $TestDrive '11cc') -DoIt Smart -Preview
            $res | Should -Not -BeNullOrEmpty
            $res | Should -HaveCount 1
            $res[0].Artist | Should -Be '10cc'
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
                    [pscustomobject]@{ Artist = [pscustomobject]@{ Name='M11CA'; Id='X1' }; Score = 0.8 },
                    [pscustomobject]@{ Artist = [pscustomobject]@{ Name='CC116'; Id='X2' }; Score = 0.8 }
                )
            }
            Mock Get-SpotifyAlbumMatches {
                param([string]$AlbumName)
                # Album search points to the real artist '10cc'
                @([pscustomobject]@{
                    AlbumName = 'Sheet Music'
                    Score = 1.0
                    Artists = @([pscustomobject]@{ Name='10cc'; Id='ART10' })
                })
            }
            Mock Get-SpotifyArtistAlbums {
                @([pscustomobject]@{ Name = 'Sheet Music'; AlbumType='album'; ReleaseDate='2007-01-01' })
            }
        }

        It 'infers artist from albums in Smart mode and proceeds with validation' {
            $res = Invoke-MuFo -Path (Join-Path $TestDrive '11cc') -DoIt Smart -Preview
            $res | Should -Not -BeNullOrEmpty
            $res | Should -HaveCount 1
            $res[0].Artist | Should -Be '10cc'
            $res[0].ArtistSource | Should -Be 'inferred'
            $res[0].NewFolderName | Should -Be '2007 - Sheet Music'
        }
    }
}
