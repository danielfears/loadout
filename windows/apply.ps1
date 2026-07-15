[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Plan", "Apply", "Check")]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [string]$LoadoutRoot,

    [Parameter(Mandatory = $true)]
    [string]$CascadiaVersion
)

$ErrorActionPreference = "Stop"
$script:Drift = 0
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$manifestDir = Join-Path $LoadoutRoot "manifests"
$configDir = Join-Path $LoadoutRoot "config"
Set-Location -LiteralPath $env:TEMP

function Write-Converged {
    param([string]$Message)
    if ($Mode -eq "Check") {
        Write-Host "  [OK] $Message"
    }
}

function Write-Drift {
    param([string]$Message)
    $script:Drift++
    $prefix = if ($Mode -eq "Apply") { "[APPLY]" } else { "[$Mode]" }
    Write-Host "  $prefix $Message"
}

function Backup-File {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Copy-Item -LiteralPath $Path -Destination "$Path.bak.$timestamp"
    }
}

function Ensure-WingetPackage {
    param(
        [string]$Id,
        [string]$Version
    )

    $result = winget.exe list `
        --id $Id `
        --exact `
        --accept-source-agreements `
        --disable-interactivity 2>$null
    $packageLine = $result |
        Where-Object { $_ -match [regex]::Escape($Id) } |
        Select-Object -First 1
    $installed = $LASTEXITCODE -eq 0 -and $null -ne $packageLine
    $installedVersion = ""
    if ($installed -and
        $packageLine -match (
            [regex]::Escape($Id) + "\s+(\S+)"
        )) {
        $installedVersion = $Matches[1]
    }
    $versionMatches = $installed -and (
        $Version -eq "-" -or
        $installedVersion -eq $Version
    )
    if ($versionMatches) {
        Write-Converged "$Id $Version"
        return
    }

    Write-Drift "install $Id $Version"
    if ($Mode -ne "Apply") {
        return
    }

    $arguments = @(
        "install",
        "--id", $Id,
        "--exact",
        "--silent",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--disable-interactivity",
        "--force"
    )
    if ($Version -ne "-") {
        $arguments += @("--version", $Version)
    }
    winget.exe @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "winget failed to install $Id"
    }
}

function Ensure-File {
    param(
        [string]$Label,
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Source file not found: $Source"
    }
    if (Test-Path -LiteralPath $Destination) {
        $sourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
        $destinationHash = (
            Get-FileHash -LiteralPath $Destination -Algorithm SHA256
        ).Hash
        if ($sourceHash -eq $destinationHash) {
            Write-Converged $Label
            return
        }
    }

    Write-Drift "configure $Label"
    if ($Mode -ne "Apply") {
        return
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) `
        -Force | Out-Null
    Backup-File $Destination
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Merge-JsonObjects {
    param(
        [object]$Base,
        [object]$Overlay
    )

    foreach ($property in $Overlay.PSObject.Properties) {
        $Base | Add-Member `
            -MemberType NoteProperty `
            -Name $property.Name `
            -Value $property.Value `
            -Force
    }
    return $Base
}

function Ensure-JsonOverlay {
    param(
        [string]$Label,
        [string]$OverlayPath,
        [string]$Destination
    )

    $overlay = Get-Content -LiteralPath $OverlayPath -Raw | ConvertFrom-Json
    if (Test-Path -LiteralPath $Destination) {
        try {
            $base = Get-Content -LiteralPath $Destination -Raw |
                ConvertFrom-Json
        }
        catch {
            $base = [pscustomobject]@{}
        }
    }
    else {
        $base = [pscustomobject]@{}
    }
    $merged = Merge-JsonObjects -Base $base -Overlay $overlay
    $desired = $merged | ConvertTo-Json -Depth 30
    $current = if (Test-Path -LiteralPath $Destination) {
        Get-Content -LiteralPath $Destination -Raw
    }
    else {
        ""
    }
    if ($current.Trim() -eq $desired.Trim()) {
        Write-Converged $Label
        return
    }

    Write-Drift "merge $Label"
    if ($Mode -ne "Apply") {
        return
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) `
        -Force | Out-Null
    Backup-File $Destination
    Set-Content -LiteralPath $Destination -Value $desired -Encoding UTF8
}

function Ensure-CascadiaFont {
    $fontDirectory = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    $registryPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    $fonts = @(
        @{
            File = "CascadiaCodeNF.ttf"
            Name = "Cascadia Code NF (TrueType)"
        },
        @{
            File = "CascadiaMonoNF.ttf"
            Name = "Cascadia Mono NF (TrueType)"
        }
    )
    $missing = $false
    foreach ($font in $fonts) {
        $fontPath = Join-Path $fontDirectory $font.File
        $entry = Get-ItemPropertyValue `
            -Path $registryPath `
            -Name $font.Name `
            -ErrorAction SilentlyContinue
        if (-not (Test-Path -LiteralPath $fontPath) -or -not $entry) {
            $missing = $true
        }
    }
    if (-not $missing) {
        Write-Converged "Cascadia Nerd Fonts"
        return
    }

    Write-Drift "install Cascadia Nerd Fonts $CascadiaVersion"
    if ($Mode -ne "Apply") {
        return
    }
    $temporary = Join-Path ([IO.Path]::GetTempPath()) `
        "loadout-font-$timestamp"
    New-Item -ItemType Directory -Path $temporary -Force | Out-Null
    try {
        $archive = Join-Path $temporary "CascadiaCode.zip"
        $url = "https://github.com/microsoft/cascadia-code/releases/download/v$CascadiaVersion/CascadiaCode-$CascadiaVersion.zip"
        Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
        Expand-Archive -LiteralPath $archive -DestinationPath $temporary -Force
        New-Item -ItemType Directory -Path $fontDirectory -Force | Out-Null
        New-Item -Path $registryPath -Force | Out-Null

        foreach ($font in $fonts) {
            $source = Get-ChildItem -Path $temporary -Recurse -File |
                Where-Object { $_.Name -eq $font.File } |
                Select-Object -First 1
            if (-not $source) {
                throw "Font missing from archive: $($font.File)"
            }
            $destination = Join-Path $fontDirectory $font.File
            Copy-Item $source.FullName $destination -Force
            New-ItemProperty `
                -Path $registryPath `
                -Name $font.Name `
                -Value $destination `
                -PropertyType String `
                -Force | Out-Null
        }
    }
    finally {
        Remove-Item -LiteralPath $temporary -Recurse -Force `
            -ErrorAction SilentlyContinue
    }
}

function Get-CodeCommand {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin\code.cmd"),
        (Join-Path $env:ProgramFiles "Microsoft VS Code\bin\code.cmd")
    )
    return $candidates |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1
}

function Ensure-VSCodeExtensions {
    param([string]$Manifest)

    $code = Get-CodeCommand
    if (-not $code) {
        Write-Drift "make the VS Code command available"
        if ($Mode -eq "Apply") {
            throw "VS Code command not found after package convergence"
        }
        return
    }
    $current = & $code --list-extensions --show-versions
    foreach ($line in Get-Content -LiteralPath $Manifest) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            continue
        }
        if ($current -contains $line) {
            Write-Converged "VS Code extension $line"
            continue
        }
        Write-Drift "install VS Code extension $line"
        if ($Mode -eq "Apply") {
            & $code --install-extension $line --force
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to install VS Code extension: $line"
            }
        }
    }
}

function Test-PowerShellModules {
    param([string]$Manifest)

    $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if (-not $pwsh) {
        Write-Drift "make PowerShell available before module convergence"
        return $false
    }
    foreach ($line in Get-Content -LiteralPath $Manifest) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            continue
        }
        $name, $version = $line -split "`t", 2
        $output = & $pwsh.Source -NoProfile -NonInteractive -Command `
            "`$m=Get-Module -ListAvailable '$name' | Where-Object Version -eq '$version' | Select-Object -First 1; if(`$m){`$m.Version.ToString()}"
        if ($output -eq $version) {
            Write-Converged "PowerShell module $name $version"
        }
        else {
            Write-Drift "install PowerShell module $name $version"
            return $false
        }
    }
    return $true
}

foreach ($line in Get-Content -LiteralPath `
    (Join-Path $manifestDir "windows-packages.tsv")) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
        continue
    }
    $id, $version = $line -split "`t", 2
    Ensure-WingetPackage -Id $id -Version $version
}

Ensure-CascadiaFont

$terminalFragment = Join-Path $env:LOCALAPPDATA `
    "Microsoft\Windows Terminal\fragments\Loadout\loadout.json"
Ensure-File `
    -Label "Windows Terminal Loadout fragment" `
    -Source (Join-Path $configDir "windows-terminal.fragment.json") `
    -Destination $terminalFragment

Ensure-JsonOverlay `
    -Label "VS Code settings" `
    -OverlayPath (Join-Path $configDir "vscode-settings.json") `
    -Destination (Join-Path $env:APPDATA "Code\User\settings.json")
Ensure-JsonOverlay `
    -Label "Copilot settings" `
    -OverlayPath (Join-Path $configDir "copilot-settings.json") `
    -Destination (Join-Path $HOME ".copilot\settings.json")
Ensure-File `
    -Label "Copilot instructions" `
    -Source (Join-Path $configDir "copilot-instructions.md") `
    -Destination (Join-Path $HOME ".copilot\copilot-instructions.md")

$modulesConverged = Test-PowerShellModules `
    -Manifest (Join-Path $manifestDir "powershell-modules.tsv")
if ($Mode -eq "Apply" -and -not $modulesConverged) {
    $pwsh = Get-Command pwsh.exe -ErrorAction Stop
    & $pwsh.Source -NoProfile -NonInteractive -File `
        (Join-Path $LoadoutRoot "scripts\install-powershell-modules.ps1") `
        -Manifest (Join-Path $manifestDir "powershell-modules.tsv")
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to install Windows PowerShell modules"
    }
}

Ensure-VSCodeExtensions `
    -Manifest (Join-Path $manifestDir "vscode-windows-extensions.txt")

if ($script:Drift -gt 0 -and $Mode -ne "Apply") {
    exit 2
}
exit 0
