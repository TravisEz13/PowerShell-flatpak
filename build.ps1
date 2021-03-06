#!/usr/bin/env pwsh
[CmdletBinding(DefaultParameterSetName = 'Build')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Bootstrap')]
    [switch] $Bootstrap,

    [Parameter(Mandatory, ParameterSetName = 'Build')]
    [switch] $Build,
    [Parameter(Mandatory, ParameterSetName = 'Install')]
    [switch] $Install,
    [Parameter(Mandatory, ParameterSetName = 'Uninstall')]
    [switch] $Uninstall,
    [Parameter(Mandatory, ParameterSetName = 'Run')]
    [switch] $Run,
    [Parameter()]
    [ValidateSet('Stable','Preview','Servicing')][string] $Release = 'Stable'
)

if (!$IsLinux) {
    throw "Current, this requires linux!"
}

$metadataUrl = 'https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/metadata.json'
$metadata = Invoke-RestMethod -Uri $metadataUrl

switch ($Release) {
    'Stable'{$ReleaseTag = $metadata.StableReleaseTag}
    'Preview'{$ReleaseTag = $metadata.PreviewReleaseTag}
    'Servicing'{$ReleaseTag = $metadata.ServicingReleaseTag}
    default {throw "Incorrect Release Specified: $Release"}
}

$version = $ReleaseTag -replace '^v'
$packageUrl = "https://github.com/PowerShell/PowerShell/releases/download/v$version/powershell-$version-linux-x64.tar.gz"

if ($Bootstrap.IsPresent) {
    #Get Linux System Information
    $LinuxInfo = Get-Content /etc/os-release | ConvertFrom-StringData
    $Environment = [PSCustomObject]@{
        IsUbuntu            = $LinuxInfo.Id -match 'ubuntu'
        IsCentOS            = $LinuxInfo.Id -match 'centos'
        IsFedora            = $LinuxInfo.Id -match 'fedora'
        IsOpenSUSE          = $LinuxInfo.Id -match 'opensuse'
    }

    if($Environment.IsUbuntu){
        sudo apt update
        sudo apt install -y flatpak flatpak-builder
    }
    elseif($Environment.IsFedora){
        sudo dnf check-update
        sudo dnf -y install flatpak flatpak-builder
    }
    elseif($Environment.IsOpenSUSE){
        sudo zypper refresh
        sudo zypper -n install flatpak flatpak-builder
    }
    
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    sudo flatpak -y install flathub org.freedesktop.Platform//20.08 org.freedesktop.Sdk//20.08
}

if ($Build.IsPresent) {
    Push-Location
    Set-Location $PSScriptRoot

    try {
        Invoke-WebRequest -Uri $packageUrl -OutFile "/tmp/powershell-$version-linux-x64.tar.gz" -ErrorAction Stop
        $ReleaseHash = (Get-FileHash -Algorithm SHA256 -Path "/tmp/powershell-$version-linux-x64.tar.gz" -ErrorAction Stop | Select-Object -ExpandProperty Hash).ToLower()
    }
    catch {
        throw 
    }
    
    $packageJson = Get-Content -Raw -Path "$PSScriptRoot/com.microsoft.powershell.json" | ConvertFrom-Json -Depth 100

    #Update Package URL and Hash
    $packageJson.modules.sources.url    = $packageUrl
    $packageJson.modules.sources.sha256 = $ReleaseHash

    #Update Flatpak JSON file 
    $packageJson | ConvertTo-Json -Depth 100 | Set-Content -Path "$PSScriptRoot/com.microsoft.powershell.json" -Force

    try {
        sudo flatpak-builder --verbose ./build-dir com.microsoft.powershell.json --force-clean --repo=repo
        flatpak build-bundle -v ./repo powershell.flatpak com.microsoft.powershell
    }
    finally {
        pop-location
    }
}

If ($Install.IsPresent) {
    Push-Location
    Set-Location $PSScriptRoot

    if(Test-Path -Path "$PSScriptRoot/powershell.flatpak"){
        try {
            sudo flatpak install -y powershell.flatpak
        }
        finally {
            pop-location
        }
    }
}

If ($Uninstall.IsPresent) {
    Push-Location
    Set-Location $PSScriptRoot

    try {
        sudo flatpak uninstall -y powershell
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
