<#
write a function that finds 
Find me the URL for the download of the latest version of the following software:
- 7Zip
- OBS Studio
- VSCode
- PS 7.4
- PS 7.5
- PS 7.6
- .Net 8.0
- .Net 10.0

and outs to a ps object

#>

function Find-SoftwareDownloadURLs {
    <#
    .SYNOPSIS
        Finds the latest download URLs for common software using GitHub API and vendor APIs.
    .OUTPUTS
        PSCustomObject[] with properties: Software, Version, DownloadURL
    #>
    [CmdletBinding()]
    param()

    $results = @()

    # --- 7-Zip (from 7-zip.org download page) ---
    Write-Verbose "Fetching 7-Zip latest version..."
    try {
        $page = Invoke-RestMethod -Uri 'https://www.7-zip.org/download.html' -ErrorAction Stop
        if ($page -match 'href="(a/7z(\d+)-x64\.exe)"') {
            $version = $Matches[2] -replace '(\d{2})(\d{2})', '$1.$2'
            $url = "https://www.7-zip.org/$($Matches[1])"
            $results += [PSCustomObject]@{ Software = '7-Zip'; Version = $version; DownloadURL = $url }
        }
    }
    catch { Write-Warning "7-Zip: $($_.Exception.Message)" }

    # --- OBS Studio (GitHub API) ---
    Write-Verbose "Fetching OBS Studio latest version..."
    try {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/obsproject/obs-studio/releases/latest' -ErrorAction Stop
        $asset = $release.assets | Where-Object { $_.name -match 'OBS-Studio.*-Windows.*\.exe$' -and $_.name -notmatch 'pdbs' } | Select-Object -First 1
        if ($asset) {
            $results += [PSCustomObject]@{ Software = 'OBS Studio'; Version = $release.tag_name; DownloadURL = $asset.browser_download_url }
        }
    }
    catch { Write-Warning "OBS Studio: $($_.Exception.Message)" }

    # --- VSCode (update API) ---
    Write-Verbose "Fetching VSCode latest version..."
    try {
        $vscodeInfo = Invoke-RestMethod -Uri 'https://update.code.visualstudio.com/api/update/win32-x64/stable/latest' -ErrorAction Stop
        $results += [PSCustomObject]@{ Software = 'VSCode'; Version = $vscodeInfo.productVersion; DownloadURL = $vscodeInfo.url }
    }
    catch { Write-Warning "VSCode: $($_.Exception.Message)" }

    # --- PowerShell versions (GitHub API) ---
    $psVersions = @(
        @{ Major = '7.4'; Pattern = '^v7\.4\.' }
        @{ Major = '7.5'; Pattern = '^v7\.5\.' }
        @{ Major = '7.6'; Pattern = '^v7\.6\.' }
    )

    Write-Verbose "Fetching PowerShell releases..."
    try {
        $psReleases = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases?per_page=50' -ErrorAction Stop
        foreach ($psVer in $psVersions) {
            $release = $psReleases | Where-Object { $_.tag_name -match $psVer.Pattern -and -not $_.prerelease } | Select-Object -First 1
            if (-not $release) {
                # Fall back to pre-release if no stable found
                $release = $psReleases | Where-Object { $_.tag_name -match $psVer.Pattern } | Select-Object -First 1
            }
            if ($release) {
                $asset = $release.assets | Where-Object { $_.name -match 'PowerShell-.*-win-x64\.msi$' } | Select-Object -First 1
                if ($asset) {
                    $results += [PSCustomObject]@{ Software = "PowerShell $($psVer.Major)"; Version = $release.tag_name; DownloadURL = $asset.browser_download_url }
                }
            } else {
                Write-Warning "PowerShell $($psVer.Major): No release found"
            }
        }
    }
    catch { Write-Warning "PowerShell: $($_.Exception.Message)" }

    # --- .NET versions (dotnet release index API) ---
    $dotnetVersions = @('8.0', '10.0')

    foreach ($dotnetVer in $dotnetVersions) {
        Write-Verbose "Fetching .NET $dotnetVer latest version..."
        try {
            $releaseIndex = Invoke-RestMethod -Uri "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/$dotnetVer/releases.json" -ErrorAction Stop
            $latestRelease = $releaseIndex.releases | Select-Object -First 1
            if ($latestRelease) {
                $sdk = $latestRelease.sdk
                $sdkFile = $sdk.files | Where-Object { $_.rid -eq 'win-x64' -and $_.name -match '\.exe$' } | Select-Object -First 1
                if ($sdkFile) {
                    $results += [PSCustomObject]@{ Software = ".NET $dotnetVer SDK"; Version = $sdk.version; DownloadURL = $sdkFile.url }
                }
                $runtime = $latestRelease.runtime
                $runtimeFile = $runtime.files | Where-Object { $_.rid -eq 'win-x64' -and $_.name -match '\.exe$' } | Select-Object -First 1
                if ($runtimeFile) {
                    $results += [PSCustomObject]@{ Software = ".NET $dotnetVer Runtime"; Version = $runtime.version; DownloadURL = $runtimeFile.url }
                }
            }
        }
        catch { Write-Warning ".NET ${dotnetVer}: $($_.Exception.Message)" }
    }

    return $results
}

# Run and output
$Downloads = Find-SoftwareDownloadURLs -Verbose
$Downloads | Format-Table -AutoSize