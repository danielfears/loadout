[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Manifest
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Manifest)) {
    throw "PowerShell module manifest not found: $Manifest"
}

$repository = Get-PSRepository -Name PSGallery -ErrorAction Stop
if ($repository.InstallationPolicy -ne "Trusted") {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

foreach ($line in Get-Content -LiteralPath $Manifest) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
        continue
    }

    $name, $version = $line -split "`t", 2
    $installed = Get-Module -ListAvailable -Name $name |
        Where-Object { $_.Version -eq [version]$version } |
        Select-Object -First 1
    if ($installed) {
        Write-Host "[OK] $name $version"
        continue
    }

    Write-Host "[INSTALL] $name $version"
    Install-Module -Name $name `
        -RequiredVersion $version `
        -Repository PSGallery `
        -Scope CurrentUser `
        -Force `
        -AllowClobber `
        -AcceptLicense
}
