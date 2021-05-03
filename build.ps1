#!/usr/bin/env pwsh
[CmdletBinding(DefaultParameterSetName = 'Build')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Bootstrap')]
    [switch] $Bootstrap,

    [Parameter(Mandatory, ParameterSetName = 'Build')]
    [switch] $Build,
    [Parameter(ParameterSetName = 'Build')]
    [switch] $Run
)

if (!$IsLinux) {
    throw "Current, this requires linux!"
}

$metadataUrl = 'https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/metadata.json'
$metadata = Invoke-RestMethod -Uri $metadataUrl
$stableReleaseTag = $metadata.StableReleaseTag
$version = $stableReleaseTag -replace '^v'
$packageUrl = "https://github.com/PowerShell/PowerShell/releases/download/v$version/powershell-$version-linux-x64.tar.gz"

if ($Bootstrap.IsPresent) {
    sudo apt update
    sudo apt install flatpak flatpak-builder
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    sudo flatpak -y install flathub org.freedesktop.Platform//19.08 org.freedesktop.Sdk//19.08
}

if ($Build.IsPresent) {
    Push-Location
    Set-Location $PSScriptRoot
    try {
        sudo flatpak-builder --verbose ./build-dir com.microsoft.powershell.json --force-clean --repo=repo
        flatpak build-bundle -v ./repo powershell.flatpak com.microsoft.powershell
    }
    finally {
        pop-location
    }
}

If ($Run.IsPresent) {
    Push-Location
    Set-Location $PSScriptRoot
    try {
        sudo flatpak-builder --run ./build-dir com.microsoft.powershell.json pwsh
    }
    finally {
        pop-location
    }
}
