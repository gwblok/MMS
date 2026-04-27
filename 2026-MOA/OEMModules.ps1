<#
.SYNOPSIS
    Downloads OEM-related PowerShell modules, scripts, and repositories to a central location.

.DESCRIPTION
    This script provides a centralized way to manage downloads of:
    - PowerShell modules (from PowerShell Gallery)
    - Individual scripts (from GitHub raw content)
    - Complete GitHub repositories (via git clone)

.PARAMETER DownloadPath
    The root directory where all downloads will be stored.
    Default: C:\GitHub\OEMModules

.PARAMETER ModulesOnly
    If specified, only download PowerShell modules.

.PARAMETER ScriptsOnly
    If specified, only download individual scripts.

.PARAMETER ReposOnly
    If specified, only clone GitHub repositories.

.EXAMPLE
    .\OEMModules.ps1
    # Downloads everything to C:\GitHub\OEMModules

.EXAMPLE
    .\OEMModules.ps1 -DownloadPath "D:\OEMTools" -ModulesOnly
    # Downloads only modules to D:\OEMTools

.NOTES
    To add more modules, scripts, or repos: edit the arrays near the beginning of the script.
#>

param(
    [string]$DownloadPath = "C:\GitHub\OEMModules",
    [switch]$ModulesOnly,
    [switch]$ScriptsOnly,
    [switch]$ReposOnly,
    [string]$GitHubToken  # Optional: GitHub Personal Access Token for better rate limits
)

# If no switches specified, download everything
if (-not ($ModulesOnly -or $ScriptsOnly -or $ReposOnly)) {
    $ModulesOnly = $ScriptsOnly = $ReposOnly = $true
}

# ============================================================================
# CONFIGURATION: EASY TO ADD/REMOVE ITEMS
# ============================================================================

# PowerShell Modules to download
$ModulesToDownload = @(
    "HPCMSL",
    "Lenovo.Client.Scripting",
    "Lenovo.Bios.Config",
    "Lenovo.Bios.Certificates"
)

# Individual scripts to download (GitHub raw URLs)
$ScriptsToDownload = @(
    @{
        Name = "Dell-EMPS.ps1"
        Url = "https://raw.githubusercontent.com/gwblok/garytown/master/hardware/Dell/CommandUpdate/EMPS/Dell-EMPS.ps1"
    }
    # Add more scripts here as needed:
    # @{
    #     Name = "SomeScript.ps1"
    #     Url = "https://raw.githubusercontent.com/owner/repo/branch/path/file.ps1"
    # }
)

# GitHub folders to download (downloads all .ps1 files from the folder)
$GitHubFoldersToDownload = @(
    @{
        Owner = "gwblok"
        Repo = "garytown"
        Branch = "master"
        FolderPath = "hardware/HP/EMPS"
        FolderName = "HP-EMPS"  # Optional: name for subfolder, defaults to last folder name
    }
    # Add more folders here as needed:
    # @{
    #     Owner = "owner"
    #     Repo = "repo"
    #     Branch = "main"
    #     FolderPath = "path/to/folder"
    # }
)

# GitHub repositories to clone (full repository clones)
$ReposToClone = @(
    @{
        Name = "Endpoint-Management-Script-Library"
        Url = "https://github.com/dell/Endpoint-Management-Script-Library.git"
        Branch = "main"
    },
    @{
        Name = "Dell-Tools-Intune-Install"
        Url = "https://github.com/svenriebedell/Dell-Tools-Intune-Install.git"
        Branch = "main"
    }
)

# ============================================================================
# FUNCTIONS
# ============================================================================

function Initialize-Directories {
    <#
    .SYNOPSIS
        Creates necessary directories for modules, scripts, and repos.
    #>
    param([string]$BasePath)
    
    $directories = @(
        $BasePath,
        (Join-Path $BasePath "Modules"),
        (Join-Path $BasePath "Scripts"),
        (Join-Path $BasePath "Repositories")
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            Write-Host "Creating directory: $dir" -ForegroundColor Cyan
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
}

function Download-Modules {
    <#
    .SYNOPSIS
        Downloads PowerShell modules to the Modules subdirectory.
    #>
    param(
        [string]$DownloadPath,
        [string[]]$ModuleNames
    )
    
    $modulesPath = Join-Path $DownloadPath "Modules"
    
    Write-Host "`n========== DOWNLOADING MODULES ==========" -ForegroundColor Green
    
    foreach ($moduleName in $ModuleNames) {
        try {
            Write-Host "Downloading module: $moduleName" -ForegroundColor Yellow
            Save-Module -Name $moduleName -Path $modulesPath -Force -AcceptLicense
            Write-Host "✓ Successfully saved: $moduleName" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Failed to download $moduleName : $_" -ForegroundColor Red
        }
    }
}

function Download-Scripts {
    <#
    .SYNOPSIS
        Downloads individual scripts from GitHub raw URLs.
    #>
    param(
        [string]$DownloadPath,
        [object[]]$Scripts
    )
    
    $scriptsPath = Join-Path $DownloadPath "Scripts"
    
    Write-Host "`n========== DOWNLOADING SCRIPTS ==========" -ForegroundColor Green
    
    foreach ($script in $Scripts) {
        try {
            $fileName = $script.Name
            $url = $script.Url
            $filePath = Join-Path $scriptsPath $fileName
            
            Write-Host "Downloading script: $fileName" -ForegroundColor Yellow
            Invoke-WebRequest -Uri $url -OutFile $filePath -UseBasicParsing
            Write-Host "✓ Successfully saved: $fileName" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Failed to download $($script.Name) : $_" -ForegroundColor Red
        }
    }
}

function Download-GitHubFolder {
    <#
    .SYNOPSIS
        Downloads all files from a specific GitHub folder recursively.
        Uses the same logic as Install-iPXEWS.ps1
    #>
    param(
        [string]$DownloadPath,
        [object[]]$Folders,
        [string]$GitHubToken
    )
    
    $scriptsPath = Join-Path $DownloadPath "Scripts"
    
    Write-Host "`n========== DOWNLOADING GITHUB FOLDERS ==========" -ForegroundColor Green
    
    foreach ($folder in $Folders) {
        try {
            $owner = $folder.Owner
            $repo = $folder.Repo
            $branch = $folder.Branch ?? "main"
            $folderPath = $folder.FolderPath
            $folderName = $folder.FolderName ?? ($folderPath -split '/' | Select-Object -Last 1)
            
            Write-Host "Fetching contents from: $owner/$repo/$folderPath (branch: $branch)" -ForegroundColor Yellow
            
            # GitHub URLs
            $GitHubBrowseUrl = "https://github.com/$owner/$repo/tree/$branch/$folderPath"
            $GitHubApiUrl = "https://api.github.com/repos/$owner/$repo/contents/$folderPath" + "?ref=$branch"
            $GitHubRawUrl = "https://raw.githubusercontent.com/$owner/$repo/$branch"
            
            Write-Host "Browse URL: $GitHubBrowseUrl" -ForegroundColor Cyan
            
            # Prepare request headers
            $headers = @{
                'Accept' = 'application/vnd.github.v3+json'
            }
            if ($GitHubToken) {
                $headers['Authorization'] = "token $GitHubToken"
            }
            
            # Create subfolder for this GitHub folder
            $folderScriptsPath = Join-Path $scriptsPath $folderName
            if (-not (Test-Path $folderScriptsPath)) {
                New-Item -ItemType Directory -Path $folderScriptsPath -Force | Out-Null
            }
            
            # Recursive function to download directory contents
            function Get-GitHubDirectoryRecursive {
                param(
                    [string]$ApiUrl,
                    [string]$LocalBasePath,
                    [string]$RelativeBasePath = "",
                    [string]$BaseFolderPath,
                    [hashtable]$Headers
                )
                
                try {
                    Write-Host "  Fetching: $ApiUrl" -ForegroundColor DarkCyan
                    $response = Invoke-RestMethod -Uri $ApiUrl -Headers $Headers -ErrorAction Stop
                    
                    $downloadCount = 0
                    $successCount = 0
                    
                    foreach ($item in $response) {
                        $relativePath = if ($RelativeBasePath) { "$RelativeBasePath/$($item.name)" } else { $item.name }
                        $localPath = Join-Path $LocalBasePath $relativePath
                        
                        if ($item.type -eq "file") {
                            $downloadCount++
                            # Construct raw file URL
                            $fileUrl = "$GitHubRawUrl/$BaseFolderPath/$relativePath"
                            
                            # Create directory if needed
                            $localDir = Split-Path $localPath -Parent
                            if (!(Test-Path $localDir)) {
                                New-Item -ItemType Directory -Path $localDir -Force | Out-Null
                            }
                            
                            try {
                                Write-Host "    ✓ $relativePath" -ForegroundColor Green
                                $webClient = New-Object System.Net.WebClient
                                $webClient.DownloadFile($fileUrl, $localPath)
                                $successCount++
                            }
                            catch {
                                Write-Host "    ✗ Failed: $relativePath - $_" -ForegroundColor Red
                            }
                        }
                        elseif ($item.type -eq "dir") {
                            Write-Host "  Entering subdirectory: $relativePath" -ForegroundColor Cyan
                            $subApiUrl = $item.url
                            $subCounts = Get-GitHubDirectoryRecursive -ApiUrl $subApiUrl -LocalBasePath $LocalBasePath -RelativeBasePath $relativePath -BaseFolderPath $BaseFolderPath -Headers $Headers
                            $downloadCount += $subCounts.Total
                            $successCount += $subCounts.Success
                        }
                    }
                    
                    return @{ Total = $downloadCount; Success = $successCount }
                }
                catch {
                    Write-Host "  ✗ Failed to fetch directory: $($_.Exception.Message)" -ForegroundColor Red
                    return @{ Total = 0; Success = 0 }
                }
            }
            
            # Start recursive download
            $results = Get-GitHubDirectoryRecursive -ApiUrl $GitHubApiUrl -LocalBasePath $folderScriptsPath -BaseFolderPath $folderPath -Headers $headers
            
            Write-Host "Download Summary for $($folderName)" -ForegroundColor Green
            Write-Host "  Total files: $($results.Total)" -ForegroundColor White
            Write-Host "  Successfully downloaded: $($results.Success)" -ForegroundColor Green
            if ($results.Total - $results.Success -gt 0) {
                Write-Host "  Failed downloads: $($results.Total - $results.Success)" -ForegroundColor Red
            }
            Write-Host ""
        }
        catch {
            Write-Host "✗ Failed to download from folder: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Clone-Repositories {
    <#
    .SYNOPSIS
        Clones GitHub repositories to the Repositories subdirectory.
    #>
    param(
        [string]$DownloadPath,
        [object[]]$Repos
    )
    
    $reposPath = Join-Path $DownloadPath "Repositories"
    
    Write-Host "`n========== CLONING REPOSITORIES ==========" -ForegroundColor Green
    
    # Check if git is available
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "✗ Git is not installed or not in PATH. Cannot clone repositories." -ForegroundColor Red
        return
    }
    
    foreach ($repo in $Repos) {
        try {
            $repoName = $repo.Name
            $repoUrl = $repo.Url
            $repoBranch = $repo.Branch ?? "main"
            $repoPath = Join-Path $reposPath $repoName
            
            # Skip if already cloned
            if (Test-Path $repoPath) {
            Write-Host "  Repository already exists $($repoName) (updating...)" -ForegroundColor Cyan
                Push-Location $repoPath
                git pull origin $repoBranch 2>&1 | Out-Null
                Pop-Location
                Write-Host "✓ Updated: $repoName" -ForegroundColor Green
            }
            else {
                Write-Host "Cloning repository $($repoName) from branch $($repoBranch)" -ForegroundColor Yellow
                git clone --branch $repoBranch $repoUrl $repoPath 2>&1 | Out-Null
                Write-Host "✓ Successfully cloned: $repoName" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "✗ Failed to clone $($repo.Name) : $_" -ForegroundColor Red
        }
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host "OEM Modules, Scripts, and Repositories Downloader" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Download Path: $DownloadPath`n" -ForegroundColor Cyan

# Initialize directories
Initialize-Directories -BasePath $DownloadPath

# Execute based on switches
if ($ModulesOnly) {
    Download-Modules -DownloadPath $DownloadPath -ModuleNames $ModulesToDownload
}

if ($ScriptsOnly) {
    Download-Scripts -DownloadPath $DownloadPath -Scripts $ScriptsToDownload
    Download-GitHubFolder -DownloadPath $DownloadPath -Folders $GitHubFoldersToDownload -GitHubToken $GitHubToken
}

if ($ReposOnly) {
    Clone-Repositories -DownloadPath $DownloadPath -Repos $ReposToClone
}

Write-Host "`n" -ForegroundColor Cyan
Write-Host "========== DOWNLOAD COMPLETE ==========" -ForegroundColor Green
Write-Host "Downloaded to: $DownloadPath" -ForegroundColor Cyan
Write-Host "`nDirectory structure:" -ForegroundColor Cyan
Write-Host "  ├─ Modules/" -ForegroundColor Gray
Write-Host "  ├─ Scripts/" -ForegroundColor Gray
Write-Host "  └─ Repositories/" -ForegroundColor Gray
