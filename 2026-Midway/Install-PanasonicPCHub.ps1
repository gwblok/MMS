<#
.SYNOPSIS
	Installs the latest Panasonic PC Hub.

.DESCRIPTION
	Reads Panasonic's Deployment Support Tools page, finds matching Panasonic
	PC Hub installer links, selects the highest four-part version, downloads
	the installer with BITS, and silently installs it.

.NOTES
	Run as Administrator or ConfigMgr SYSTEM.
#>

$ErrorActionPreference = 'Stop'
$PCHubPageUrl = 'https://global-pc-support.connect.panasonic.com/driver/deployment-support-tools'
$FallbackUrl = 'https://dl-pc-support.connect.panasonic.com/public/soft_first/store_app/mei-ppchubinstaller-4.11.1100.300-w10w11-nologo-Multi-d20264547.exe'
$DownloadPath = Join-Path $env:ProgramData 'Panasonic\PCHub'

function Get-LatestPanasonicPCHubInstaller {
	param (
		[Parameter(Mandatory)]
		[string]$PageUrl,
		[Parameter(Mandatory)]
		[string]$FallbackUrl
	)

	try {
		$page = Invoke-WebRequest -Uri $PageUrl -UseBasicParsing -ErrorAction Stop
		$pattern = 'https://dl-pc-support\.connect\.panasonic\.com/public/soft_first/store_app/mei-ppchubinstaller-(?<Version>\d+\.\d+\.\d+\.\d+)-w10w11-nologo-Multi-d\d+\.exe'
		$matches = [regex]::Matches($page.Content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

		$installers = foreach ($match in $matches) {
			[pscustomobject]@{
				Version = [version]$match.Groups['Version'].Value
				Url = $match.Value
			}
		}

		$latest = $installers | Sort-Object Version -Descending | Select-Object -First 1
		if ($latest) {
			return $latest
		}

		Write-Warning 'No matching PCHub installer was found on the Panasonic page. Using the fallback URL.'
	}
	catch {
		Write-Warning "Could not retrieve the Panasonic PCHub page. Using the fallback URL. $($_.Exception.Message)"
	}

	$fallbackMatch = [regex]::Match($FallbackUrl, 'mei-ppchubinstaller-(?<Version>\d+\.\d+\.\d+\.\d+)-', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
	$fallbackVersion = if ($fallbackMatch.Success) { [version]$fallbackMatch.Groups['Version'].Value } else { $null }
	return [pscustomobject]@{
		Version = $fallbackVersion
		Url = $FallbackUrl
	}
}

function Get-PanasonicPCHubInstalled {
	Get-ItemProperty @(
		'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
		'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
	) -ErrorAction SilentlyContinue |
		Where-Object { $_.DisplayName -like '*Panasonic PCHub*' } |
		Select-Object -First 1
}

try {
	$installedHub = Get-PanasonicPCHubInstalled
	if ($installedHub) {
		Write-Host "Panasonic PCHub is already installed: $($installedHub.DisplayVersion)" -ForegroundColor Green
		exit 0
	}

	$installer = Get-LatestPanasonicPCHubInstaller -PageUrl $PCHubPageUrl -FallbackUrl $FallbackUrl
	Write-Host "Selected Panasonic PCHub version: $($installer.Version)" -ForegroundColor Cyan
	Write-Host "Installer URL: $($installer.Url)" -ForegroundColor Cyan

	New-Item -Path $DownloadPath -ItemType Directory -Force | Out-Null
	$installerPath = Join-Path $DownloadPath ([System.IO.Path]::GetFileName(([uri]$installer.Url).AbsolutePath))

	try {
		Start-BitsTransfer -Source $installer.Url -Destination $installerPath -DisplayName 'Panasonic PCHub' -ErrorAction Stop
	}
	catch {
		Write-Warning "BITS download failed. Falling back to Invoke-WebRequest. $($_.Exception.Message)"
		Invoke-WebRequest -Uri $installer.Url -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
	}

	if (-not (Test-Path -LiteralPath $installerPath)) {
		throw "PCHub installer was not downloaded to $installerPath."
	}

	Write-Host "Installing Panasonic PCHub from $installerPath" -ForegroundColor Cyan
	$process = Start-Process -FilePath $installerPath -ArgumentList '-silent' -Wait -PassThru -NoNewWindow
	Write-Host "PCHub installer exit code: $($process.ExitCode)"

	$stagedSetup = Get-ChildItem -Path 'C:\util2' -Filter 'Setup.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
	$RebootRequired = $false
	if ($stagedSetup) {
		Write-Host "Running staged PCHub setup: $($stagedSetup.FullName)" -ForegroundColor Cyan
		$setupProcess = Start-Process -FilePath $stagedSetup.FullName -ArgumentList '-s' -Wait -PassThru -NoNewWindow
		Write-Host "Staged PCHub setup exit code: $($setupProcess.ExitCode)"
		if ($setupProcess.ExitCode -notin @(0, 3010)) {
			throw "Staged PCHub setup failed with exit code $($setupProcess.ExitCode)."
		}
		$RebootRequired = $setupProcess.ExitCode -eq 3010
	}

	$installedHub = Get-PanasonicPCHubInstalled
	if (-not $installedHub) {
		throw "PCHub installation did not register successfully. Bootstrap exit code: $($process.ExitCode)."
	}

	Write-Host "Panasonic PCHub installation completed successfully: $($installedHub.DisplayVersion)" -ForegroundColor Green
	Write-Host "Reboot required: $RebootRequired" -ForegroundColor Yellow
	exit 0
}
catch {
	Write-Error "Failed to install Panasonic PCHub. $($_.Exception.Message)"
	exit 1
}

