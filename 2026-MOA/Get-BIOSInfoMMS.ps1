<#
.SYNOPSIS
Standalone BIOS compliance check for Dell, HP, and Lenovo devices.

.DESCRIPTION
This script detects the local OEM, reads the currently installed BIOS version,
queries the OEM online catalog for the latest BIOS version, compares current vs latest,
and returns compliance status.

The script is self-contained and does not import or depend on local OEM modules/scripts.

.PARAMETER AsObject
Returns a full result object with manufacturer, model, current/latest BIOS values,
dates (when available), source, and compliance boolean.

.PARAMETER Quiet
Suppresses formatted host output. Useful when only the boolean (or object) return
value is needed for automation.

.OUTPUTS
Default:
- [bool] True when BIOS is current, False when an update is available.

With -AsObject:
- PSCustomObject with properties:
	Manufacturer, Model, CurrentBiosVersion, LatestBiosVersion,
	CurrentBiosDate, LatestBiosDate, IsCurrent, Source

.EXAMPLE
.\Get-BIOSInfoMMS.ps1
Displays BIOS comparison details and returns True/False.

.EXAMPLE
.\Get-BIOSInfoMMS.ps1 -Quiet
Returns only True/False with no host output.

.EXAMPLE
.\Get-BIOSInfoMMS.ps1 -AsObject
Returns full structured output for reporting/JSON export.

.EXAMPLE
$result = .\Get-BIOSInfoMMS.ps1 -AsObject -Quiet
if (-not $result.IsCurrent) {
		Write-Host "BIOS update required for $($result.Model)"
}

.NOTES
Requirements:
- Internet access to OEM catalog endpoints.
- Windows with CIM/WMI access.
- Uses built-in tools/cmdlets such as Invoke-WebRequest, expand.exe, and Get-CimInstance.
- Run in an elevated PowerShell session (Run as Administrator).

OEM catalog sources used:
- Dell CatalogIndexPC / model catalog
- HP Image Assistant (HPIA) platform/reference catalogs
- Lenovo machine type catalog XML

Behavior notes:
- Some OEMs expose versions in different formats than SMBIOS strings.
- Version normalization/comparison is handled internally where possible.
- On unexpected catalog/schema/network errors, the script throws and exits with code 1.
#>

[CmdletBinding()]
param(
	[switch]$AsObject,
	[switch]$Quiet
)

# Update this value whenever the script is modified.
$ScriptVersionTimestamp = '2026.04.27-12.25'
Write-Output "Script Version: $ScriptVersionTimestamp"

function Test-IsAdministrator {
	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object Security.Principal.WindowsPrincipal($identity)
	return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
	Write-Error 'This script must be run as Administrator. Open PowerShell as Administrator and try again.'
	exit 1
}

function Invoke-DownloadFile {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Url,
		[Parameter(Mandatory = $true)]
		[string]$Destination
	)

	$destinationFolder = Split-Path -Path $Destination -Parent
	if (-not (Test-Path -Path $destinationFolder)) {
		$null = New-Item -Path $destinationFolder -ItemType Directory -Force
	}

	Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -ErrorAction Stop
}

function Expand-CabFile {
	param(
		[Parameter(Mandatory = $true)]
		[string]$CabPath,
		[Parameter(Mandatory = $true)]
		[string]$DestinationFile
	)

	$destinationFolder = Split-Path -Path $DestinationFile -Parent
	if (-not (Test-Path -Path $destinationFolder)) {
		$null = New-Item -Path $destinationFolder -ItemType Directory -Force
	}

	if (Test-Path -Path $DestinationFile) {
		Remove-Item -Path $DestinationFile -Force -ErrorAction SilentlyContinue
	}

	$expandExe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\expand.exe'
	$null = & $expandExe $CabPath $DestinationFile

	if (-not (Test-Path -Path $DestinationFile)) {
		throw "Failed to expand CAB file $CabPath"
	}
}

function Get-TempWorkingPath {
	$localAppDataTemp = if ($env:LOCALAPPDATA) {
		Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Temp'
	}
	$userProfileTemp = if ($env:USERPROFILE) {
		Join-Path -Path $env:USERPROFILE -ChildPath 'AppData\Local\Temp'
	}

	$candidates = @(
		$localAppDataTemp,
		$userProfileTemp,
		$env:TEMP,
		$env:TMP,
		([System.IO.Path]::GetTempPath()),
		(Join-Path -Path $env:SystemRoot -ChildPath 'Temp'),
		'C:\Temp'
	) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

	foreach ($base in $candidates) {
		try {
			$expandedBase = [Environment]::ExpandEnvironmentVariables($base)
			if (-not (Test-Path -Path $expandedBase)) {
				$null = New-Item -Path $expandedBase -ItemType Directory -Force -ErrorAction Stop
			}

			$path = Join-Path -Path $expandedBase -ChildPath 'OEMBiosInfo'
			if (-not (Test-Path -Path $path)) {
				$null = New-Item -Path $path -ItemType Directory -Force -ErrorAction Stop
			}

			# Validate effective write access for this user/session.
			$probeFile = Join-Path -Path $path -ChildPath '.__write_test'
			$null = New-Item -Path $probeFile -ItemType File -Force -ErrorAction Stop
			Remove-Item -Path $probeFile -Force -ErrorAction Stop

			if (Test-Path -Path $path) {
				return $path
			}
		}
		catch {
			continue
		}
	}

	throw 'Unable to create a writable temporary working path.'
}

function Get-ComputerDetails {
	$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
	$bios = Get-CimInstance -ClassName Win32_BIOS
	$product = Get-CimInstance -ClassName Win32_ComputerSystemProduct
	$baseBoard = Get-CimInstance -ClassName Win32_BaseBoard

	[PSCustomObject]@{
		Manufacturer        = $computerSystem.Manufacturer
		Model               = $computerSystem.Model
		SystemSkuNumber     = $computerSystem.SystemSKUNumber
		SMBIOSBIOSVersion   = $bios.SMBIOSBIOSVersion
		BIOSMajorVersion    = $bios.SystemBIOSMajorVersion
		BIOSMinorVersion    = $bios.SystemBIOSMinorVersion
		ReleaseDate         = $bios.ReleaseDate
		ProductName         = $product.Name
		ProductVersion      = $product.Version
		BaseBoardProduct    = $baseBoard.Product
	}
}

function ConvertTo-ComparableVersion {
	param(
		[AllowNull()]
		[string]$VersionString
	)

	if ([string]::IsNullOrWhiteSpace($VersionString)) {
		return $null
	}

	$primaryMatch = [regex]::Match($VersionString, '\d+(?:\.\d+){1,3}')
	if ($primaryMatch.Success) {
		try {
			return [version]$primaryMatch.Value
		}
		catch {
		}
	}

	$parts = [regex]::Matches($VersionString, '\d+') | ForEach-Object { $_.Value }
	if ($parts.Count -ge 2) {
		$joined = ($parts | Select-Object -First 4) -join '.'
		try {
			return [version]$joined
		}
		catch {
		}
	}

	return $null
}

function Get-ResultObject {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Manufacturer,
		[Parameter(Mandatory = $true)]
		[string]$Model,
		[Parameter(Mandatory = $true)]
		[string]$CurrentBiosVersion,
		[Parameter(Mandatory = $true)]
		[string]$LatestBiosVersion,
		[Parameter(Mandatory = $true)]
		[bool]$IsCurrent,
		[string]$CurrentBiosDate,
		[string]$LatestBiosDate,
		[string]$Source
	)

	[PSCustomObject]@{
		Manufacturer       = $Manufacturer
		Model              = $Model
		CurrentBiosVersion = $CurrentBiosVersion
		LatestBiosVersion  = $LatestBiosVersion
		CurrentBiosDate    = $CurrentBiosDate
		LatestBiosDate     = $LatestBiosDate
		IsCurrent          = $IsCurrent
		Source             = $Source
	}
}

function Get-DellSupportedModelsStandalone {
	$workingPath = Get-TempWorkingPath
	$cabPath = Join-Path -Path $workingPath -ChildPath 'CatalogIndexPC.cab'
	$xmlPath = Join-Path -Path $workingPath -ChildPath 'CatalogIndexPC.xml'

	Invoke-DownloadFile -Url 'https://downloads.dell.com/catalog/CatalogIndexPC.cab' -Destination $cabPath
	Expand-CabFile -CabPath $cabPath -DestinationFile $xmlPath

	[xml]$catalogXml = Get-Content -Path $xmlPath
	$supportedModels = foreach ($supportedModel in $catalogXml.ManifestIndex.GroupManifest) {
		[PSCustomObject]@{
			SystemID = [string]$supportedModel.SupportedSystems.Brand.Model.systemID
			Model    = [string]$supportedModel.SupportedSystems.Brand.Model.Display.'#cdata-section'
			Url      = [string]$supportedModel.ManifestInformation.path
			Date     = [string]$supportedModel.ManifestInformation.version
		}
	}

	return $supportedModels
}

function Get-DellLatestBiosInfo {
	param(
		[Parameter(Mandatory = $true)]
		[pscustomobject]$ComputerDetails
	)

	$supportedModel = Get-DellSupportedModelsStandalone | Where-Object { $_.SystemID -match $ComputerDetails.SystemSkuNumber } | Select-Object -First 1
	if (-not $supportedModel) {
		throw "Dell System SKU $($ComputerDetails.SystemSkuNumber) was not found in the Dell catalog"
	}

	$workingPath = Get-TempWorkingPath
	$cabPath = Join-Path -Path $workingPath -ChildPath 'CatalogIndexModel.cab'
	$xmlPath = Join-Path -Path $workingPath -ChildPath 'CatalogIndexModel.xml'
	Invoke-DownloadFile -Url ("https://downloads.dell.com/{0}" -f $supportedModel.Url) -Destination $cabPath
	Expand-CabFile -CabPath $cabPath -DestinationFile $xmlPath

	[xml]$catalogXml = Get-Content -Path $xmlPath
	$baseUrl = "https://{0}" -f $catalogXml.Manifest.baseLocation

	$biosUpdates = foreach ($component in $catalogXml.Manifest.SoftwareComponent) {
		$type = [string]$component.ComponentType.Display.'#cdata-section'
		if ($type -notin @('BIOS', 'bios')) {
			continue
		}

		[PSCustomObject]@{
			Name        = [string]$component.Name.Display.'#cdata-section'
			ReleaseDate = [datetime]$component.releaseDate
			DellVersion = [string]$component.dellVersion
			Path        = "{0}/{1}" -f $baseUrl, [string]$component.path
		}
	}

	$latest = $biosUpdates | Sort-Object -Property ReleaseDate -Descending | Select-Object -First 1
	if (-not $latest) {
		throw 'No Dell BIOS update was found in the Dell catalog'
	}

	$currentComparable = ConvertTo-ComparableVersion -VersionString $ComputerDetails.SMBIOSBIOSVersion
	$latestComparable = ConvertTo-ComparableVersion -VersionString $latest.DellVersion
	$isCurrent = $false

	if ($currentComparable -and $latestComparable) {
		$isCurrent = $currentComparable -ge $latestComparable
	}
	else {
		$isCurrent = ($ComputerDetails.SMBIOSBIOSVersion -eq $latest.DellVersion)
	}

	return (Get-ResultObject -Manufacturer 'Dell' -Model $ComputerDetails.Model -CurrentBiosVersion $ComputerDetails.SMBIOSBIOSVersion -LatestBiosVersion $latest.DellVersion -CurrentBiosDate ([string]$ComputerDetails.ReleaseDate) -LatestBiosDate ([string]$latest.ReleaseDate) -IsCurrent $isCurrent -Source 'Dell Catalog')
}

function Get-LenovoMachineTypeStandalone {
	param(
		[Parameter(Mandatory = $true)]
		[pscustomobject]$ComputerDetails
	)

	return $ComputerDetails.ProductName.Substring(0, 4)
}

function Get-LenovoCurrentBiosVersionStandalone {
	param(
		[Parameter(Mandatory = $true)]
		[pscustomobject]$ComputerDetails
	)

	if ($ComputerDetails.ProductVersion -like 'ThinkPad*') {
		$major = [string]$ComputerDetails.BIOSMajorVersion
		$minor = ([string]$ComputerDetails.BIOSMinorVersion).PadLeft(2, '0')
		return "$major.$minor"
	}

	if ($ComputerDetails.ProductVersion -like 'ThinkCentre*' -or $ComputerDetails.ProductVersion -like 'ThinkStation*') {
		$hex = '0x' + $ComputerDetails.SMBIOSBIOSVersion.Substring(5, 2)
		return ([string]$ComputerDetails.BIOSMajorVersion + '.' + [Convert]::ToInt32($hex, 16))
	}

	return $ComputerDetails.SMBIOSBIOSVersion
}

function Get-LenovoXmlFile {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Url
	)

	$xmlFile = $null
	$stop = $false
	$retryCount = 0
	$status = $null

	do {
		try {
			[System.Xml.XmlDocument]$xmlFile = (New-Object System.Net.WebClient).DownloadString($Url)
			$stop = $true
		}
		catch {
			if ($retryCount -gt 3) {
				$stop = $true
				$status = $_
			}
			else {
				$retryCount = $retryCount + 1
			}
		}
	}
	while (-not $stop)

	if ($null -eq $xmlFile) {
		switch -Wildcard ($status) {
			'*400*' { throw "$($Url): Bad Request (400)" }
			'*401*' { throw "$($Url): Unauthorized (401)" }
			'*403*' { throw "$($Url): Forbidden (403)" }
			'*404*' { throw "$($Url): Not Found (404)" }
			'*407*' { throw "$($Url): Proxy Authentication Required (407)" }
			'*408*' { throw "$($Url): Request Timeout (408)" }
			'*500*' { throw "$($Url): Internal Server Error (500)" }
			'*501*' { throw "$($Url): Not Implemented (501)" }
			'*502*' { throw "$($Url): Bad Gateway (502)" }
			'*503*' { throw "$($Url): Service Unavailable (503)" }
			'*504*' { throw "$($Url): Gateway Timeout (504)" }
			default { throw "$($Url): Unknown exception `n$status" }
		}
	}

	return $xmlFile
}

function Get-LenovoDatCatalog {
	return Get-LenovoXmlFile -Url 'https://download.lenovo.com/cdrt/td/catalogv2.xml'
}

function Get-LenovoCatalogBiosDetails {
	param(
		[Parameter(Mandatory = $true)]
		[pscustomobject]$ComputerDetails
	)

	$machineType = Get-LenovoMachineTypeStandalone -ComputerDetails $ComputerDetails
	$catalog = Get-LenovoDatCatalog
	$node = $catalog.ModelList.Model | Where-Object { $_.Types.Type.Contains($machineType.ToUpper().Trim()) } | Select-Object -First 1

	if (-not $node) {
		throw "No Lenovo BIOS DAT catalog entry was found for machine type $machineType"
	}

	$catalogUrls = @(
		"https://download.lenovo.com/catalog/${machineType}_Win11.xml",
		"https://download.lenovo.com/catalog/${machineType}_Win10.xml"
	)

	$catalogXml = $null
	foreach ($catalogUrl in $catalogUrls) {
		try {
			$catalogXml = Get-LenovoXmlFile -Url $catalogUrl
			if ($catalogXml) {
				break
			}
		}
		catch {
			continue
		}
	}

	if (-not $catalogXml) {
		throw "No Lenovo BIOS catalog entries were found for machine type $machineType"
	}

	$packageUrls = @($catalogXml.packages.ChildNodes | Where-Object { $_.category -match 'BIOS UEFI' } | ForEach-Object { $_.location })
	if ($packageUrls.Count -eq 0) {
		throw "No Lenovo BIOS package entries were found for machine type $machineType"
	}

	$highestVersion = $null
	$highestReleaseDate = $null
	$highestUpdateUrl = $null
	$highestReadmeUrl = $null

	foreach ($packageUrl in $packageUrls) {
		try {
			$packageXml = Get-LenovoXmlFile -Url $packageUrl
			$baseUrl = $packageUrl.Substring(0, $packageUrl.LastIndexOf('/') + 1)
			$packageVersion = [string]$packageXml.Package.version
			$updateUrl = $baseUrl + $packageXml.Package.Files.Installer.File.Name
			$readmeUrl = if ($packageXml.Package.Files.ReadMe.File.Name) { $baseUrl + $packageXml.Package.Files.ReadMe.File.Name } else { $null }
			$releaseDate = [string]$packageXml.Package.ReleaseDate

			if ($ComputerDetails.ProductVersion -like 'ThinkCentre*' -or $ComputerDetails.ProductVersion -like 'ThinkStation*') {
				$packageVersionHex = '0x' + $packageVersion.Substring(5, 2)
				$packageVersion = '1.' + [Convert]::ToInt32($packageVersionHex, 16)
			}

			$packageComparable = ConvertTo-ComparableVersion -VersionString $packageVersion
			$highestComparable = ConvertTo-ComparableVersion -VersionString $highestVersion
			if (($null -eq $highestVersion) -or ($packageComparable -and $highestComparable -and $packageComparable -gt $highestComparable) -or ($packageComparable -and -not $highestComparable)) {
				$highestVersion = $packageVersion
				$highestReleaseDate = $releaseDate
				$highestUpdateUrl = $updateUrl
				$highestReadmeUrl = $readmeUrl
			}
		}
		catch {
			continue
		}
	}

	if (-not $highestVersion) {
		throw 'No Lenovo BIOS version could be parsed from the Lenovo catalog'
	}

	[PSCustomObject]@{
		MachineType       = $machineType
		ImageCode         = [string]$node.BIOS.image
		AvailableVersion  = $highestVersion
		ReleaseDate       = $highestReleaseDate
		UpdateUrl         = $highestUpdateUrl
		ReadmeUrl         = $highestReadmeUrl
	}
}

function Get-LenovoLatestBiosInfo {
	param(
		[Parameter(Mandatory = $true)]
		[pscustomobject]$ComputerDetails
	)

	$currentVersion = Get-LenovoCurrentBiosVersionStandalone -ComputerDetails $ComputerDetails
	$biosDetails = Get-LenovoCatalogBiosDetails -ComputerDetails $ComputerDetails

	$currentComparable = ConvertTo-ComparableVersion -VersionString $currentVersion
	$latestComparable = ConvertTo-ComparableVersion -VersionString $biosDetails.AvailableVersion
	$isCurrent = $false

	if ($currentComparable -and $latestComparable) {
		$isCurrent = $currentComparable -ge $latestComparable
	}
	else {
		$isCurrent = ($currentVersion -eq $biosDetails.AvailableVersion)
	}

	return (Get-ResultObject -Manufacturer 'Lenovo' -Model $ComputerDetails.Model -CurrentBiosVersion $currentVersion -LatestBiosVersion $biosDetails.AvailableVersion -CurrentBiosDate ([string]$ComputerDetails.ReleaseDate) -LatestBiosDate $biosDetails.ReleaseDate -IsCurrent $isCurrent -Source 'Lenovo Catalog')
}

function Get-HPPlatformListXml {
	$workingPath = Get-TempWorkingPath
	$cabPath = Join-Path -Path $workingPath -ChildPath 'HPPlatformList.cab'
	$xmlPath = Join-Path -Path $workingPath -ChildPath 'HPPlatformList.xml'
	Invoke-DownloadFile -Url 'https://hpia.hpcloud.hp.com/ref/platformList.cab' -Destination $cabPath
	Expand-CabFile -CabPath $cabPath -DestinationFile $xmlPath
	[xml]$xml = Get-Content -Path $xmlPath
	return $xml
}

function Get-HPSupportedOsInfo {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Platform
	)

	$platformXml = Get-HPPlatformListXml
	$osList = ($platformXml.ImagePal.Platform | Where-Object { $_.SystemID -match $Platform }).OS | Select-Object OSReleaseIdDisplay, OSBuildId, OSDescription
	if (-not $osList) {
		throw "No HP OS support information was found for platform $Platform"
	}

	$maxOsSupported = ($osList.OSDescription | Where-Object { $_ -notmatch 'LTSB' } | Select-Object -Unique | Measure-Object -Maximum).Maximum
	$maxReleaseId = (($osList | Where-Object { $_.OSDescription -eq $maxOsSupported }).OSReleaseIdDisplay | Measure-Object -Maximum).Maximum
	$maxOsNumber = if ($maxOsSupported -match '11') { '11.0' } else { '10.0' }

	[PSCustomObject]@{
		OSNumber  = $maxOsNumber
		ReleaseId = $maxReleaseId
	}
}

function Get-HPLatestBiosInfo {
	param(
		[Parameter(Mandatory = $true)]
		[pscustomobject]$ComputerDetails
	)

	$platform = $ComputerDetails.BaseBoardProduct
	$osInfo = Get-HPSupportedOsInfo -Platform $platform
	$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') { '64' } else { '32' }
	$cabUrl = ("https://hpia.hpcloud.hp.com/ref/{0}/{0}_{1}_{2}.{3}.cab" -f $platform, $arch, $osInfo.OSNumber, $osInfo.ReleaseId).ToLower()

	$workingPath = Get-TempWorkingPath
	$cabPath = Join-Path -Path $workingPath -ChildPath 'HPIA.cab'
	$xmlPath = Join-Path -Path $workingPath -ChildPath 'HPIA.xml'
	Invoke-DownloadFile -Url $cabUrl -Destination $cabPath
	Expand-CabFile -CabPath $cabPath -DestinationFile $xmlPath

	[xml]$xml = Get-Content -Path $xmlPath
	$biosUpdates = @($xml.ImagePal.Solutions.UpdateInfo | Where-Object { $_.Category -match 'bios' -or $_.Name -match 'bios' })
	if (-not $biosUpdates) {
		throw "No HP BIOS update was found for platform $platform"
	}

	$latest = $biosUpdates |
		Sort-Object -Property @(
			@{ Expression = { if ($_.ReleaseDate) { [datetime]$_.ReleaseDate } else { [datetime]::MinValue } }; Descending = $true },
			@{ Expression = { [string]$_.Version }; Descending = $true }
		) |
		Select-Object -First 1
	$currentVersion = [string]$ComputerDetails.SMBIOSBIOSVersion
	$latestVersion = [string]$latest.Version

	$currentComparable = ConvertTo-ComparableVersion -VersionString $currentVersion
	$latestComparable = ConvertTo-ComparableVersion -VersionString $latestVersion
	$isCurrent = $false

	if ($currentComparable -and $latestComparable) {
		$isCurrent = $currentComparable -ge $latestComparable
	}
	else {
		$isCurrent = ($currentVersion -eq $latestVersion)
	}

	return (Get-ResultObject -Manufacturer 'HP' -Model $ComputerDetails.Model -CurrentBiosVersion $currentVersion -LatestBiosVersion $latestVersion -CurrentBiosDate ([string]$ComputerDetails.ReleaseDate) -LatestBiosDate ([string]$latest.ReleaseDate) -IsCurrent $isCurrent -Source 'HP Image Assistant Reference Catalog')
}

function Get-BiosComplianceInfo {
	$computerDetails = Get-ComputerDetails
	$manufacturer = [string]$computerDetails.Manufacturer

	if ($manufacturer -match 'Dell') {
		return Get-DellLatestBiosInfo -ComputerDetails $computerDetails
	}

	if ($manufacturer -match 'HP|Hewlett-Packard') {
		return Get-HPLatestBiosInfo -ComputerDetails $computerDetails
	}

	if ($manufacturer -match 'Lenovo') {
		return Get-LenovoLatestBiosInfo -ComputerDetails $computerDetails
	}

	throw "Unsupported manufacturer $manufacturer. This script currently supports Dell, HP, and Lenovo."
}

try {
	$result = Get-BiosComplianceInfo

	if (-not $Quiet) {
		Write-Host 'BIOS Compliance Check' -ForegroundColor Cyan
		Write-Host '=====================' -ForegroundColor Cyan
		Write-Host "Manufacturer  $($result.Manufacturer)"
		Write-Host "Model         $($result.Model)"
		Write-Host "Current BIOS  $($result.CurrentBiosVersion)"
		Write-Host "Latest BIOS   $($result.LatestBiosVersion)"
		if ($result.LatestBiosDate) {
			Write-Host "Latest Date   $($result.LatestBiosDate)"
		}
		Write-Host "Source        $($result.Source)"
		Write-Host "Compliant     $($result.IsCurrent)"
	}

	if ($AsObject) {
		$result
	}
	else {
		$result.IsCurrent
	}
}
catch {
	Write-Error $_.Exception.Message
}
