$ErrorActionPreference = "Stop"

# Function to download a file if it does not exist
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

# Function to add directory to PATH if not already present
function Add-ToPath {
    param (
        [string]$Directory
    )
    $currentPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
    
    if ($currentPath -notlike "*$Directory*") {
        Write-Output "Adding $Directory to PATH"
        $newPath = $currentPath + ";$Directory"
        [System.Environment]::SetEnvironmentVariable('Path', $newPath, [System.EnvironmentVariableTarget]::Machine)
    } else {
        Write-Output "$Directory is already in PATH"
    }
}

function Compare-String {
    param(
      [String] $string1,
      [String] $string2
    )
    if ( $string1 -ceq $string2 ) {
      return -1
    }
    for ( $i = 0; $i -lt $string1.Length; $i++ ) {
      if ( $string1[$i] -cne $string2[$i] ) {
        Write-Host "one='$([byte][char]$string1[$i])'  two='$([byte][char]$string2[$i])'"
        return $i
      }
    }
    return $string1.Length
  }

# Define Variables
$DownloadPath = "C:\Temp"
$DockerCliVersion = "28.0.1"
$DockerCliFileUrl = "https://download.docker.com/win/static/stable/x86_64/docker-$($DockerCliVersion).zip"
$DockerCliTempPath = "$($DownloadPath)\docker-$($DockerCliVersion).zip"
$DockerCliInstallPath = "C:\Program Files\DockerCLI"

$DockerComposeVersion = "2.33.1"
$DockerComposeFileUrl = "https://github.com/docker/compose/releases/download/v$($DockerComposeVersion)/docker-compose-windows-x86_64.exe"
$DockerComposeTempPath = "$($DownloadPath)\docker-compose-windows-x86_64.exe"
$DockerComposeInstallPath = "C:\Program Files\DockerCLI"    

$DockerBuildXVersion = "0.21.2"
$DockerBuildXFileUrl = "https://github.com/docker/buildx/releases/download/v$($DockerBuildXVersion)/buildx-v$($DockerBuildXVersion).windows-amd64.exe"
$DockerBuildXTempPath = "$($DownloadPath)\buildx-v$($DockerBuildXVersion).windows-amd64.exe"
$DockerBuildXInstallPath = "$($env:USERPROFILE)\.docker\cli-plugins"

$UnboundVersion = "1.20.0"
$UnboundFileUrl = "https://nlnetlabs.nl/downloads/unbound/unbound-$($UnboundVersion).zip"
$UnboundTempPath = "$($DownloadPath)\unbound-$($UnboundVersion).zip"
$UnboundInstallPath = "C:\Program Files\Unbound"    

# Create Download Path if it does not exist
if (-not (Test-Path $DownloadPath)) {
    New-Item -Path $DownloadPath -ItemType Directory
}

# Ensure Docker CLI is installed
if (-not (Test-Path (Join-Path $DockerCliInstallPath 'docker.exe'))) {
    # Download Docker CLI
    Download-File -Uri $DockerCliFileUrl -OutputPath $DockerCliTempPath

    # Create Docker CLI Install Directory
    if (-not (Test-Path $DockerCliInstallPath)) {
        New-Item -Path $DockerCliInstallPath -ItemType Directory
    }

    # Extract Docker CLI
    Write-Output "Extracting Docker CLI to $DockerCliInstallPath"
    Expand-Archive -Path $DockerCliTempPath -DestinationPath $DockerCliInstallPath -Force

    # Update PATH Environment Variable
    Add-ToPath -Directory $DockerCliInstallPath

} else {
    Write-Output "Docker CLI is already installed"
}

# Set Docker CLI Context
$ipAddresses = wsl bash -c "hostname -I"
$wslIp = $ipAddresses.Trim() -split "\s+" | Select-Object -First 1
$dockerContextEndpoint="tcp://$($wslIp):2375"

$dockerContexts = docker context ls --format '{{.Name}}\t{{.Current}}\t{{.DockerEndpoint}}'
$currentDockerContext = $dockerContexts | Where-Object { $_ -match "true" }

if ($currentDockerContext) {
    $currentDockerContextParts = $currentDockerContext -split "\t"
    $currentDockerContextEndpoint = $currentDockerContextParts[2]

    if ($dockerContextEndpoint -ne $currentDockerContextEndpoint) {
        Write-Output "Updating Docker context 'wsl' with endpoint $dockerContextEndpoint"
        docker context update wsl --docker "host=$dockerContextEndpoint"
    } else {
        Write-Output "Docker Context is already 'wsl'"
    }
    docker context use wsl
} else {
    Write-Output "Creating Docker context 'wsl' with endpoint $dockerContextEndpoint"
    docker context create wsl --docker "host=$dockerContextEndpoint"
    docker context use wsl
}

# Ensure Docker Compose is installed
if (-not (Test-Path (Join-Path $DockerComposeInstallPath 'docker-compose.exe'))) {
    # Download Docker Compose
    Download-File -Uri $DockerComposeFileUrl -OutputPath $DockerComposeTempPath

    # Create Docker Compose Install Directory
    if (-not (Test-Path $DockerComposeInstallPath)) {
        New-Item -Path $DockerComposeInstallPath -ItemType Directory
    }

    # Install Docker Compose
    Write-Output "Installing Docker Compose to $DockerComposeInstallPath"
    Copy-Item -Path $DockerComposeTempPath -Destination (Join-Path $DockerComposeInstallPath 'docker-compose.exe') -Force
} else {
    Write-Output "Docker Compose is already installed"
}

# Ensure Docker BuildX is installed
if (-not (Test-Path (Join-Path $DockerBuildXInstallPath 'buildx.exe'))) {
    # Download Docker BuildX
    Download-File -Uri $DockerBuildXFileUrl -OutputPath $DockerBuildXTempPath

    # Create Docker BuildX Install Directory
    if (-not (Test-Path $DockerBuildXInstallPath)) {
        New-Item -Path $DockerBuildXInstallPath -ItemType Directory
    }

    # Install Docker BuildX
    Write-Output "Installing Docker BuildX to $DockerBuildXInstallPath"
    Copy-Item -Path $DockerBuildXTempPath -Destination (Join-Path $DockerBuildXInstallPath 'buildx.exe') -Force
} else {
    Write-Output "Docker BuildX is already installed"
}

# # Ensure Unbound is installed
# if (-not (Test-Path (Join-Path $UnboundInstallPath 'unbound.exe'))) {
#     # Download Unbound
#     Download-File -Uri $UnboundFileUrl -OutputPath $UnboundTempPath

#     # Create Unbound Install Directory
#     if (-not (Test-Path $UnboundInstallPath)) {
#         New-Item -Path $UnboundInstallPath -ItemType Directory
#     }

#     # Extract Unbound
#     Write-Output "Extracting Unbound to $UnboundInstallPath"
#     Expand-Archive -Path $UnboundTempPath -DestinationPath $UnboundInstallPath -Force
# } else {
#     Write-Output "Unbound is already installed"
# }

# #Ensure Unbound is configured
# $currentUnboundConfig = ""
# if (Test-Path (Join-Path $UnboundInstallPath 'service.conf')) {
#     $currentUnboundConfig = Get-Content -Path "$(Join-Path $UnboundInstallPath 'service.conf')" -Raw
# } 

# # Get the current DNS server addresses for all network interfaces
# $dnsServers = Get-DnsClientServerAddress

# # Get the primary network adapter (commonly the first one in the list)
# $primaryAdapter = $dnsServers | Sort-Object InterfaceAlias | Select-Object -First 1
# $primaryDnsServer = "8.8.8.8"

# # Output the DNS server addresses for the primary adapter
# if ($primaryAdapter) {
#     $primaryDnsServer = $primaryAdapter.ServerAddresses | Select-Object -First 1
# } else {
#     Write-Output "No network adapters found."
# }

# $ingressServer = "10.152.255.3"

# $privateDomains = @(
#     "local"
# )

# $insecureDomains = @(
#     "local"
# )

# $wildcardForwarders = @(
#     @{DomainName="k8s.lan.talifun.com.";Ipv4Addresses=@($ingressServer);},
#     @{DomainName="local.";Ipv4Addresses=@($ingressServer);}
# )

# $dnsForwarders = @(
#     @{DomainName=".";DnsServers=@("$($primaryDnsServer)@53");}
# )

# $unboundConfig = @"
# # Unbound configuration file on windows.
# # See example.conf for more settings and syntax
# server:
# 	#interface: 0.0.0.0@853
# 	#interface: ::0@853

#     interface: 127.0.0.1@53
# 	interface: ::1@53

# 	access-control: 0.0.0.0/0 allow
# 	access-control: ::0/0 allow

# 	# verbosity level 0-4 of logging
# 	verbosity: 0

# 	# On windows you may want to make all the paths relative to the
# 	# directory that has the executable in it (unbound.exe).  Use this.
# 	#directory: "%EXECUTABLE%"

# 	# if you want to log to a file use
# 	logfile: "C:\Program Files\Unbound\unbound.log"
# 	log-queries: yes
# 	log-replies: yes
# 	log-local-actions: yes
# 	log-servfail: yes

# 	# or use "unbound.log" and the directory clause above to put it in
# 	# the directory where the executable is.

# 	# on Windows, this setting makes reports go into the Application log
# 	# found in ControlPanels - System tasks - Logs 
# 	#use-syslog: yes

# 	# on Windows, this setting adds the certificates from the Windows
# 	# Cert Store.  For when you want to use forwarders with TLS.
# 	tls-win-cert: yes

# 	#aggressive-nsec: no
	
#     # DNSSEC doesn't work with private TLDs so we need to mark them as insecure
# 	private-address: 10.0.0.0/8
# 	private-address: 172.16.0.0/12
# 	private-address: 192.168.0.0/16
# 	private-address: 100.64.0.0/10
#     $(
#         foreach ($privateDomain in $privateDomains) {
# @"

#     private-domain: "$($privateDomain)"
# "@
#         }
# )      
# $(
#         foreach ($insecureDomain in $insecureDomains) {
# @"

#     domain-insecure: "$($insecureDomain)"
# "@
#         }
# )    

# # remote-control:
# 	# If you want to use unbound-control.exe from the command line, use
# 	#control-enable: yes
# 	#control-interface: 127.0.0.1
# 	#control-use-cert: no

# server: 
# 	auto-trust-anchor-file: "C:\Program Files\Unbound\root.key"

# $(
#     foreach ($wildcardForwarder in $wildcardForwarders) {
# @"

# local-zone: "$($wildcardForwarder.DomainName)" redirect
# $(
#         foreach ($Ipv4Address in $wildcardForwarder.Ipv4Addresses) {
# @"

# local-data: "$($wildcardForwarder.DomainName) IN A $($Ipv4Address)"
# "@
#         }
# )

# "@
#         }
# )

# $(
#     foreach ($dnsForwarder in $dnsForwarders) {
# @"

# forward-zone:
#     name: "$($dnsForwarder.DomainName)"
# $(
#         foreach ($dnsServer in $dnsForwarder.DnsServers) {
# @"

#     forward-addr: $($dnsServer)
# "@
#         }
# )

# "@
#     }
# )

# "@

# $unboundConfig = ($unboundConfig -replace "`r`n", "`n").Trim()
# $currentUnboundConfig = ($currentUnboundConfig -replace "`r`n", "`n").Trim()

# if ($currentUnboundConfig -eq $unboundConfig) {
#     Write-Output "Unbound is already configured"
# } else {
#     [System.IO.File]::WriteAllText((Join-Path $UnboundInstallPath 'service.conf'), $unboundConfig, [System.Text.Encoding]::ASCII)
    
#     $serviceName = "Unbound"
#     $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

#     if ($null -ne $service) {
#         Write-Output "Service '$serviceName' exists."
#         Restart-Service unbound
#     } else {
#         & "$(Join-Path $UnboundInstallPath 'unbound-service-install.exe')"
#         Write-Output "Service '$serviceName' does not exist."
#         Start-Service unbound
#     }
    
#     Write-Output "Unbound configured"
# }

Write-Output "Installation completed successfully!"
