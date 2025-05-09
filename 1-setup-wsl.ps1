$ErrorActionPreference = "Stop"


#region Helper Functions

function Get-RegistryItemValue {
    param(
        [string]$KeyPath,
        [string]$ItemName
    )

    try {
        $value = Get-ItemProperty -Path $KeyPath -Name $ItemName -ErrorAction Stop | Select-Object -ExpandProperty $ItemName
    }
    catch {
        $value = $null
    }

    return $value
}

function Enable-WindowsFeature {
    param(
        [string]$FeatureName
    )

    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName
    if ($feature.State -ne 'Enabled') {
        Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName
    }
}

function Download-File {
    param (
        [string]$Uri,
        [string]$OutputPath
    )
    if (-not (Test-Path $OutputPath)) {
        Write-Output "Downloading $Uri to $OutputPath"
        Invoke-WebRequest -Uri $Uri -OutFile $OutputPath
    } else {
        Write-Output "$OutputPath already exists"
    }
}

function Install-WSL {
    param (
        [string]$DistroName
    )
    if (-not (wsl -l | Select-String $DistroName)) {
        Write-Output "Installing WSL distribution: $DistroName"
        wsl --install -d $DistroName
    } else {
        Write-Output "$DistroName is already installed"
    }
}

function Set-wslConfig {
    # # Configure wsl options
    $memory = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum / 1gb
    if ($memory -gt 8) {
        $memory = $memory - 4
    }
    $processors = (Get-ComputerInfo).CsNumberOfLogicalProcessors
    $wslConfigPath = "$env:USERPROFILE\.wslconfig"
    $wslConfig = @"
[wsl2]
ipv6=true

# by default WSL supports both but this causes issues for Kubernetes instances
kernelCommandLine = cgroup_no_v1=all

# Limits VM memory to use no more than $($memory)GB, this can be set as whole numbers using GB or MB
memory=$($memory)GB

# Sets the VM to use all the virtual processors
processors=$processors

"@

    Set-Content -Path $wslConfigPath -Value $wslConfig
}

#endregion Helper Functions


#region parameters
$WslDistribution = "Ubuntu-24.04"
$WslUsername = 'ebru' # wsl whoami
$windowsSshPath = "$($env:USERPROFILE)\.ssh"

#endregion parameters

#region parameters not used
# $WslDistributionInstallerName = "ubuntu2404"
# $WslKernelVersion = '6.6.87.1'
# $NatNetwork = '10.152.0.0/16'
# $NatGatewayIpAddress = '10.152.0.1'
# $NatIpAddress = '10.152.0.5' # 192.168.55.130

#endregion parameters not used

#region functions not used
# #Enable WSL pre-requisities
# Enable-WindowsFeature -FeatureName Microsoft-Windows-Subsystem-Linux
# Enable-WindowsFeature -FeatureName VirtualMachinePlatform


# #Configure wsl network options
# $RegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss'
# $CurrentNatNetwork = Get-RegistryItemValue -KeyPath $RegistryPath -ItemName 'NatNetwork'
# if (!$CurrentNatNetwork -or $CurrentNatNetwork -ne $NatNetwork) {
#     New-ItemProperty -Path $RegistryPath -Name 'NatNetwork' -Value $NatNetwork -PropertyType String -Force
# }

# $CurrentNatGatewayIpAddress = Get-RegistryItemValue -KeyPath $RegistryPath -ItemName 'NatGatewayIpAddress'
# if (!$CurrentNatGatewayIpAddress -or $CurrentNatGatewayIpAddress -ne $NatGatewayIpAddress) {
#     New-ItemProperty -Path $RegistryPath -Name 'NatGatewayIpAddress' -Value $NatGatewayIpAddress -PropertyType String -Force
# }


# 192.168.55.130
# $RegistryPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss'
# $CurrentNatIpAddress = Get-RegistryItemValue -KeyPath $RegistryPath -ItemName 'NatIpAddress'
# if (!$CurrentNatIpAddress -or $CurrentNatIpAddress -ne $NatIpAddress) {
#     New-ItemProperty -Path $RegistryPath -Name 'NatIpAddress' -Value $NatIpAddress -PropertyType String -Force
# }
#endregion functions not used



Write-Output "Setting up WSL distribution: $WslDistribution"
Install-WSL -DistroName $WslDistribution

Write-Output "Create $WslUsername and add it to sudoers"
wsl -d $WslDistribution -u root bash -ic "./infra/scripts/1-create-user.sh '$WslUsername'"
wsl --shutdown

Write-Output "Update the system"
wsl -d $WslDistribution -u $WslUsername bash -c "./infra/scripts/2-install-ansible.sh"

Write-Output "Install Ansible"
wsl -d $WslDistribution -u $WslUsername bash -ic "./infra/scripts/3-install-ansible-solution.sh '$windowsSshPath' '$gitRepoUri' '$NatNetwork' '$NatIpAddress' "

Write-Output "Install Ansible solution"
wsl -d $WslDistribution -u $WslUsername bash -c "./infra/scripts/4-run-ansible-solution.sh"

Write-Output "Ensure WSL Distro is restarted when first used with user account"
wsl -t $WslDistribution