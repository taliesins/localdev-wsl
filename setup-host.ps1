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

    $feature=Get-WindowsOptionalFeature -Online -FeatureName $FeatureName
    if ($feature.State -ne 'Enabled'){
        Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName
    }
}

#Enable WSL pre-requisities
Enable-WindowsFeature -FeatureName Microsoft-Windows-Subsystem-Linux
Enable-WindowsFeature -FeatureName VirtualMachinePlatform

#Setup WSL
$instance = "Ubuntu-22.04"
$env:WSL_UTF8 = "1"

wsl --shutdown
wsl --update
wsl --set-default-version 2
$foundInstance=$(wsl -l | %{$_.Replace("`0","")} | ?{$_ -match "^$($instance)"})
if (!$foundInstance){
    wsl --list --online
    wsl --install -d $instance
}
wsl --setdefault $instance
wsl --shutdown

#Download custom kernel
$kernelVersion = '6.8.0'
$wslPath = 'c:\data\wsl2'
$customKernelPath = "$($wslPath)\bzImage-x86_64"
$url = "https://github.com/taliesins/WSL2-Linux-Kernel-Rolling/releases/download/linux-wsl-stable-$($kernelVersion)/bzImage-x86_64"
New-Item -Path $wslPath -ItemType Directory -Force
$webClient = New-Object System.Net.WebClient
$webClient.DownloadFile($url, $customKernelPath)
$webClient.Dispose()

#Configure wsl network options
$RegistryPath='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss'
$NatNetwork=Get-RegistryItemValue -KeyPath $RegistryPath -ItemName 'NatNetwork'
if (!$NatNetwork) {
    $NatNetwork='10.152.0.0/16'
    New-ItemProperty -Path $RegistryPath -Name 'NatNetwork' -Value $NatNetwork -PropertyType String -Force
}

$NatGatewayIpAddress=Get-RegistryItemValue -KeyPath $RegistryPath -ItemName 'NatGatewayIpAddress'
if (!$NatGatewayIpAddress) {
    $NatGatewayIpAddress='10.152.0.1'
    New-ItemProperty -Path $RegistryPath -Name 'NatGatewayIpAddress' -Value $NatGatewayIpAddress -PropertyType String -Force
}

$RegistryPath='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss'
$NatIpAddress=Get-RegistryItemValue -KeyPath $RegistryPath -ItemName 'NatIpAddress'
if (!$NatIpAddress) {
    $NatIpAddress='10.152.0.5'
    New-ItemProperty -Path $RegistryPath -Name 'NatIpAddress' -Value $NatIpAddress -PropertyType String -Force
}

# Configure wsl options
$memory=(Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum /1gb
if ($memory -gt 8){
    $memory = $memory - 4
}
$processors=(Get-ComputerInfo).CsNumberOfLogicalProcessors
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
$nvidiaLibPath="$env:windir\System32\lxss\lib"
if (Test-Path "$nvidiaLibPath\libcuda.so.1.1"){
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

$sshPath = "$($env:USERPROFILE)\.ssh"
$copySsh = (Get-Content -Raw ./copy-dotfiles.sh).Replace("`$windows_ssh_path", $sshPath.Replace("\", "\\"))
wsl bash -c ($copySsh -replace '"', '\"')

#Install Ansible
$installAnsible = Get-Content -Raw ./install-ansible.sh
wsl bash -c ($installAnsible -replace '"', '\"')

#Setup Ansible solution
$installAnsibleSolution = Get-Content -Raw ./install-ansible-solution.sh
wsl bash -c ($installAnsibleSolution -replace '"', '\"')

#Run Ansible solution
$runAnsibleSolution = Get-Content -Raw ./run-ansible-solution.sh
wsl bash -c ($runAnsibleSolution -replace '"', '\"')
