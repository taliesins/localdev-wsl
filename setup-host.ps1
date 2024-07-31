$ErrorActionPreference = "Stop"

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

$WslDistribution = "Ubuntu-22.04"
$WslDistributionInstallerName = "ubuntu2204"
$WslInstanceName = "Ubuntu-22.04"

$WslKernelVersion = '6.10.0'
$WslKernelPath = 'c:\data\wsl2'

$NatNetwork = '10.152.0.0/16'
$NatGatewayIpAddress = '10.152.0.1'
$NatIpAddress = '10.152.0.5'

#Enable WSL pre-requisities
Enable-WindowsFeature -FeatureName Microsoft-Windows-Subsystem-Linux
Enable-WindowsFeature -FeatureName VirtualMachinePlatform

#Setup WSL instance
$env:WSL_UTF8 = "1"

wsl --shutdown
wsl --update
wsl --set-default-version 2
$foundInstance = $(wsl -l | % { $_.Replace("`0", "") } | ? { $_ -match "^$($WslInstanceName)" })
if (!$foundInstance) {
    wsl --list --online
    wsl --install $WslDistribution --no-launch
    & "$($env:LOCALAPPDATA)\Microsoft\WindowsApps\$($WslDistributionInstallerName)" install --root
    wsl --install -d $WslInstanceName
}
wsl --setdefault $WslInstanceName
wsl --shutdown

#Download custom kernel
$customKernelPath = "$($WslKernelPath)\bzImage-x86_64"
$url = "https://github.com/taliesins/WSL2-Linux-Kernel-Rolling/releases/download/linux-wsl-stable-$($WslKernelVersion)/bzImage-x86_64"
New-Item -Path $WslKernelPath -ItemType Directory -Force
$webClient = New-Object System.Net.WebClient
$webClient.DownloadFile($url, $customKernelPath)
$webClient.Dispose()

#Configure wsl network options
$RegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss'
$CurrentNatNetwork = Get-RegistryItemValue -KeyPath $RegistryPath -ItemName 'NatNetwork'
if (!$CurrentNatNetwork -or $CurrentNatNetwork -ne $NatNetwork) {
    New-ItemProperty -Path $RegistryPath -Name 'NatNetwork' -Value $NatNetwork -PropertyType String -Force
}

$CurrentNatGatewayIpAddress = Get-RegistryItemValue -KeyPath $RegistryPath -ItemName 'NatGatewayIpAddress'
if (!CurrentNatGatewayIpAddress -or $CurrentNatGatewayIpAddress -ne $NatGatewayIpAddress) {
    New-ItemProperty -Path $RegistryPath -Name 'NatGatewayIpAddress' -Value $NatGatewayIpAddress -PropertyType String -Force
}

$RegistryPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss'
$CurrentNatIpAddress = Get-RegistryItemValue -KeyPath $RegistryPath -ItemName 'NatIpAddress'
if (!$CurrentNatIpAddress -or $CurrentNatIpAddress -ne $NatIpAddress) {
    New-ItemProperty -Path $RegistryPath -Name 'NatIpAddress' -Value $NatIpAddress -PropertyType String -Force
}

# Configure wsl options
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

# Specify a custom Linux kernel to use with your installed distros. The default kernel used can be found at https://github.com/microsoft/WSL2-Linux-Kernel
kernel=$($customKernelPath.Replace("\","\\"))
"@
Set-Content -Path $wslConfigPath -Value $wslConfig

#Fix nvidia
$nvidiaLibPath = "$env:windir\System32\lxss\lib"
if (Test-Path "$nvidiaLibPath\libcuda.so.1.1") {
    if (!(Test-Path -Path "$nvidiaLibPath\libcuda.so")) {
        New-Item -Path "$nvidiaLibPath\libcuda.so" -ItemType SymbolicLink -Value "$nvidiaLibPath\libcuda.so.1.1"
    }
    if (!(Test-Path -Path "$nvidiaLibPath\libcuda.so.1")) {
        New-Item -Path "$nvidiaLibPath\libcuda.so.1" -ItemType SymbolicLink -Value "$nvidiaLibPath\libcuda.so.1.1"
    }
}

# if (!(Test-Path -Path "$env:windir\System32\DriverStore\FileRepository\nv_dispig.inf_amd64_2fe7c165c5dd3267\libdxcore.so")) {
#     New-Item -Path "$env:windir\System32\DriverStore\FileRepository\nv_dispig.inf_amd64_2fe7c165c5dd3267\libdxcore.so" -ItemType SymbolicLink -Value "$nvidiaLibPath\libdxcore.so"
# }

# Copy scripts over
$windowsCwdPath = Split-Path -Parent $PSCommandPath
$windowsSshPath = "$($env:USERPROFILE)\.ssh"
$copyFilesOverScript = (Get-Content -Raw ./1-copy-files.sh).Replace("`$windows_cwd_path", $windowsCwdPath.Replace("\", "\\")).Replace("`$windows_ssh_path", $windowsSshPath.Replace("\", "\\"))
wsl bash -c ($copyFilesOverScript -replace '"', '\"')

#Install Ansible
wsl bash -c "`$HOME/localdev-wsl-scripts/2-install-ansible.sh"

#Setup Ansible solution
$GitRepoUri = $(git config --get remote.origin.url)
if (!$GitRepoUri) {
    $GitRepoUri = 'https://github.com/taliesins/localdev-wsl.git'
}

wsl bash -c "sed -i 's/`\`$git_repo_uri/$($GitRepoUri.Replace('/', '\\\\\\/'))/g' `$HOME/localdev-wsl-scripts/3-install-ansible-solution.sh"
wsl bash -c "sed -i 's/`\`$nat_network/$($NatNetwork.Replace('/', '\\\\\\/'))/g' `$HOME/localdev-wsl-scripts/3-install-ansible-solution.sh"
wsl bash -c "sed -i 's/`\`$nat_ip_address/$($NatIpAddress.Replace('/', '\\\\\\/'))/g' `$HOME/localdev-wsl-scripts/3-install-ansible-solution.sh"
wsl bash -c "`$HOME/localdev-wsl-scripts/3-install-ansible-solution.sh"

#Run Ansible solution
wsl bash -c '$HOME/localdev-wsl-scripts/4-run-ansible-solution.sh'
