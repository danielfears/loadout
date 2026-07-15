[CmdletBinding()]
param(
    [ValidatePattern("^[a-z_][a-z0-9_-]*$")]
    [string]$LinuxUser = (($env:USERNAME -replace "[^A-Za-z0-9_-]", "").ToLower()),

    [string]$DistroName = "Ubuntu"
)

$ErrorActionPreference = "Stop"
$distribution = "Ubuntu-24.04"
$linuxRepo = "/home/$LinuxUser/loadout"
$repoRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path

function Invoke-CheckedWsl {
    param([string[]]$Arguments)

    & wsl.exe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "wsl.exe failed: $($Arguments -join ' ')"
    }
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw "Windows 11 with WSL is required."
}

$distros = @(
    (& wsl.exe --list --quiet 2>$null) |
        ForEach-Object { ($_ -replace "`0", "").Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)
if ($distros -notcontains $DistroName) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $isAdministrator = $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdministrator) {
        throw "Run bootstrap.ps1 from an elevated PowerShell to install WSL."
    }

    Write-Host "[INSTALL] $distribution as $DistroName"
    & wsl.exe --install `
        --distribution $distribution `
        --name $DistroName `
        --version 2 `
        --no-launch
    $distros = @(
        (& wsl.exe --list --quiet 2>$null) |
            ForEach-Object { ($_ -replace "`0", "").Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    if ($distros -notcontains $DistroName) {
        Write-Host "Windows must restart before recovery can continue."
        Write-Host "After restarting, run bootstrap.ps1 again."
        exit 3010
    }
}

& wsl.exe -d $DistroName -u root -- id -u $LinuxUser *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[CREATE] Linux user $LinuxUser"
    Invoke-CheckedWsl -Arguments @(
        "-d", $DistroName, "-u", "root", "--",
        "useradd", "--create-home", "--shell", "/bin/bash", $LinuxUser
    )
    Invoke-CheckedWsl -Arguments @(
        "-d", $DistroName, "-u", "root", "--",
        "usermod", "--append", "--groups", "sudo", $LinuxUser
    )
    Write-Host "Set the sudo password for $LinuxUser."
    & wsl.exe -d $DistroName -u root -- passwd $LinuxUser
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to set the Linux user password."
    }
}

& wsl.exe -d $DistroName -u root -- test -d $linuxRepo
if ($LASTEXITCODE -ne 0) {
    $linuxSource = (
        & wsl.exe -d $DistroName -u root -- wslpath -u $repoRoot
    ).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($linuxSource)) {
        throw "Unable to translate the repository path into WSL."
    }

    Write-Host "[COPY] $repoRoot -> $linuxRepo"
    Invoke-CheckedWsl -Arguments @(
        "-d", $DistroName, "-u", "root", "--",
        "mkdir", "-p", "/home/$LinuxUser"
    )
    Invoke-CheckedWsl -Arguments @(
        "-d", $DistroName, "-u", "root", "--",
        "cp", "-a", "--", $linuxSource, $linuxRepo
    )
    Invoke-CheckedWsl -Arguments @(
        "-d", $DistroName, "-u", "root", "--",
        "chown", "-R", "$LinuxUser`:$LinuxUser", $linuxRepo
    )
}

$wslConfig = "[boot]`nsystemd=true`n`n[user]`ndefault=$LinuxUser`n"
$temporaryConfig = Join-Path $env:TEMP "loadout-wsl.conf"
Set-Content -LiteralPath $temporaryConfig -Value $wslConfig -Encoding ASCII
$linuxConfig = (
    & wsl.exe -d $DistroName -u root -- wslpath -u $temporaryConfig
).Trim()
$restartRequired = $false
& wsl.exe -d $DistroName -u root -- cmp -s $linuxConfig /etc/wsl.conf
if ($LASTEXITCODE -ne 0) {
    & wsl.exe -d $DistroName -u root -- test -e /etc/wsl.conf
    if ($LASTEXITCODE -eq 0) {
        $backup = "/etc/wsl.conf.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Invoke-CheckedWsl -Arguments @(
            "-d", $DistroName, "-u", "root", "--",
            "cp", "-a", "/etc/wsl.conf", $backup
        )
    }
    Invoke-CheckedWsl -Arguments @(
        "-d", $DistroName, "-u", "root", "--",
        "cp", "--", $linuxConfig, "/etc/wsl.conf"
    )
    $restartRequired = $true
}

Invoke-CheckedWsl -Arguments @(
    "-d", $DistroName, "-u", $LinuxUser, "--",
    "chmod", "+x",
    "$linuxRepo/bootstrap.sh",
    "$linuxRepo/install.sh",
    "$linuxRepo/bin/loadout"
)

if ($restartRequired) {
    Write-Host "[RESTART] Applying WSL configuration"
    & wsl.exe --shutdown
}

$command = "cd '$linuxRepo' && ./bootstrap.sh"
Invoke-CheckedWsl -Arguments @(
    "-d", $DistroName, "-u", $LinuxUser, "--",
    "bash", "-lc", $command
)

Write-Host "Loadout complete. Open Windows Terminal and start $DistroName."
