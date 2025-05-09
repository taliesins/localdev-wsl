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
$DockerCliVersion = "28.1.1"
$DockerCliFileUrl = "https://download.docker.com/win/static/stable/x86_64/docker-$($DockerCliVersion).zip"
$DockerCliTempPath = "$($DownloadPath)\docker-$($DockerCliVersion).zip"
$DockerCliInstallPath = "C:\Program Files\DockerCLI"

$DockerComposeVersion = "2.36.0"
$DockerComposeFileUrl = "https://github.com/docker/compose/releases/download/v$($DockerComposeVersion)/docker-compose-windows-x86_64.exe"
$DockerComposeTempPath = "$($DownloadPath)\docker-compose-windows-x86_64.exe"
$DockerComposeInstallPath = "C:\Program Files\DockerCLI"    

$DockerBuildXVersion = "0.23.0"
$DockerBuildXFileUrl = "https://github.com/docker/buildx/releases/download/v$($DockerBuildXVersion)/buildx-v$($DockerBuildXVersion).windows-amd64.exe"
$DockerBuildXTempPath = "$($DownloadPath)\buildx-v$($DockerBuildXVersion).windows-amd64.exe"
$DockerBuildXInstallPath = "$($env:USERPROFILE)\.docker\cli-plugins"

# Create Download Path if it does not exist
$dockerPath=(Join-Path $DockerCliInstallPath 'docker.exe')
if (-not (Test-Path $DownloadPath)) {
    New-Item -Path $DownloadPath -ItemType Directory
}

$currentDockerCliVersion=""
if (Test-Path $dockerPath) {
    $currentDockerCliVersion=& $dockerPath version --format '{{.Client.Version}}'
}

# Ensure Docker CLI is installed
if ($currentDockerCliVersion -ne $DockerCliVersion) {
    # Download Docker CLI
    Download-File -Uri $DockerCliFileUrl -OutputPath $DockerCliTempPath

    # Create Docker CLI Install Directory
    if (-not (Test-Path $DockerCliInstallPath)) {
        New-Item -Path $DockerCliInstallPath -ItemType Directory
    }

    # Extract Docker CLI
    Write-Output "Extracting Docker CLI to $DockerCliInstallPath"
    Expand-Archive -Path $DockerCliTempPath -DestinationPath $DockerCliInstallPath -Force

    $DockerSubfolder = Join-Path $DockerCliInstallPath "docker"

    if (Test-Path $DockerSubfolder) {
        Move-Item -Path "$DockerSubfolder\*" -Destination $DockerCliInstallPath -Force
        Remove-Item -Path $DockerSubfolder
    } else {
        Write-Error "The extracted folder 'docker' was not found."
    }

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
$dockerComposePath=(Join-Path $DockerComposeInstallPath 'docker-compose.exe')
$currentDockerComposeVersion=""
if (Test-Path $dockerComposePath) {
    $versionOutput = & $dockerComposePath version 2>$null
    if ($versionOutput -match "Docker Compose version v([\d\.]+)") {
        $currentDockerComposeVersion = $matches[1]
    } else {
        throw "Could not extract Docker Compose version. Version string = $versionOutput"
    }
}

if ($currentDockerComposeVersion -ne $DockerComposeVersion) {
    # Download Docker Compose
    Download-File -Uri $DockerComposeFileUrl -OutputPath $DockerComposeTempPath

    # Create Docker Compose Install Directory
    if (-not (Test-Path $DockerComposeInstallPath)) {
        New-Item -Path $DockerComposeInstallPath -ItemType Directory
    }

    # Install Docker Compose
    Write-Output "Installing Docker Compose to $DockerComposeInstallPath"
    Copy-Item -Path $DockerComposeTempPath -Destination $dockerComposePath -Force
} else {
    Write-Output "Docker Compose is already installed"
}

# Ensure Docker BuildX is installed
$dockerBuildXPath=(Join-Path $DockerBuildXInstallPath 'docker-buildx.exe')
$currentDockerBuildXVersion=""
if (Test-Path $dockerBuildXPath) {
    $versionOutput = & $dockerBuildXPath version 2>$null
    if ($versionOutput -match "github\.com/docker/buildx v([\d\.]+)") {
        $currentDockerBuildXVersion = $matches[1]
    } else {
        throw "Could not extract Docker BuildX version. Version string = $versionOutput"
    }
}

if ($currentDockerBuildXVersion -ne $DockerBuildXVersion) {
    # Download Docker BuildX
    Download-File -Uri $DockerBuildXFileUrl -OutputPath $DockerBuildXTempPath

    # Create Docker BuildX Install Directory
    if (-not (Test-Path $DockerBuildXInstallPath)) {
        New-Item -Path $DockerBuildXInstallPath -ItemType Directory
    }

    # Install Docker BuildX
    Write-Output "Installing Docker BuildX to $DockerBuildXInstallPath"
    Copy-Item -Path $DockerBuildXTempPath -Destination $dockerBuildXPath -Force
} else {
    Write-Output "Docker BuildX is already installed"
}

Write-Output "Installation completed successfully!"
