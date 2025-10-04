# DecompilerServer Container File Watcher for Windows
# Monitors assembly files and restarts container when changes are detected

param(
    [Parameter(Mandatory=$true)]
    [string]$AssembliesPath,
    
    [string]$AssemblyFile = "Assembly-CSharp.dll",
    [string]$ContainerName = "decompiler-server",
    [string]$ImageName = "decompiler-server:latest",
    [switch]$Verbose,
    [int]$WatchInterval = 2,
    [switch]$Help
)

function Write-ColorOutput([string]$ForegroundColor, [string]$Message) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $ForegroundColor
}

function Write-Log([string]$Message) { Write-ColorOutput "Cyan" $Message }
function Write-Success([string]$Message) { Write-ColorOutput "Green" $Message }
function Write-Warning([string]$Message) { Write-ColorOutput "Yellow" "WARNING: $Message" }
function Write-Error([string]$Message) { Write-ColorOutput "Red" "ERROR: $Message" }

function Show-Usage {
    @"
DecompilerServer Container File Watcher for Windows

Usage: .\watch-container.ps1 [OPTIONS]

Parameters:
    -AssembliesPath PATH    Path to assemblies directory (required)
    -AssemblyFile FILE      Assembly filename (default: Assembly-CSharp.dll)
    -ContainerName NAME     Container name (default: decompiler-server)
    -ImageName IMAGE        Container image (default: decompiler-server:latest)
    -Verbose               Enable verbose logging
    -WatchInterval N       Watch interval in seconds (default: 2)
    -Help                  Show this help

Examples:
    .\watch-container.ps1 -AssembliesPath "C:\Games\Unity\Managed"
    .\watch-container.ps1 -AssembliesPath ".\assemblies" -Verbose
    .\watch-container.ps1 -AssembliesPath "C:\Games\Managed" -WatchInterval 1 -Verbose

"@
}

function Test-Configuration {
    if (-not (Test-Path $AssembliesPath -PathType Container)) {
        Write-Error "Assemblies directory does not exist: $AssembliesPath"
        exit 1
    }

    $assemblyFullPath = Join-Path $AssembliesPath $AssemblyFile
    if (-not (Test-Path $assemblyFullPath -PathType Leaf)) {
        Write-Error "Assembly file not found: $assemblyFullPath"
        exit 1
    }

    # Check if Docker or Podman is available
    $script:ContainerRuntime = $null
    if (Get-Command "podman" -ErrorAction SilentlyContinue) {
        $script:ContainerRuntime = "podman"
    } elseif (Get-Command "docker" -ErrorAction SilentlyContinue) {
        $script:ContainerRuntime = "docker"
    } else {
        Write-Error "Neither Docker nor Podman found. Please install one of them."
        exit 1
    }

    return $assemblyFullPath
}

function Get-FileHash([string]$FilePath) {
    try {
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
        return $hash.Hash
    } catch {
        Write-Warning "Failed to compute hash for $FilePath, using timestamp"
        $fileInfo = Get-Item $FilePath
        return "$($fileInfo.LastWriteTime.Ticks)_$($fileInfo.Length)"
    }
}

function Start-Container {
    Write-Log "Starting DecompilerServer container..."
    
    $dockerArgs = @(
        "run"
        "--name", $ContainerName
        "--rm"
        "-i"
        "-v", "${AssembliesPath}:/app/assemblies:ro"
        "-e", "ASSEMBLY_PATH=/app/assemblies/$AssemblyFile"
    )
    
    if ($Verbose) {
        $dockerArgs += @("-e", "DECOMPILER_VERBOSE=true")
    }
    
    $dockerArgs += $ImageName
    
    $script:ContainerProcess = Start-Process -FilePath $script:ContainerRuntime -ArgumentList $dockerArgs -NoNewWindow -PassThru
    Write-Success "Container started (PID: $($script:ContainerProcess.Id))"
}

function Stop-Container {
    if ($script:ContainerProcess -and -not $script:ContainerProcess.HasExited) {
        Write-Log "Stopping container..."
        try {
            & $script:ContainerRuntime stop $ContainerName 2>$null
            $script:ContainerProcess.WaitForExit(5000) | Out-Null
        } catch {
            # Force kill if graceful stop fails
            if (-not $script:ContainerProcess.HasExited) {
                $script:ContainerProcess.Kill()
            }
        }
        $script:ContainerProcess = $null
    }
}

function Initialize-Cleanup {
    # Set up cleanup on script termination
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        Write-Log "Cleaning up..."
        Stop-Container
    } | Out-Null

    # Handle Ctrl+C
    [Console]::TreatControlCAsInput = $false
    [Console]::CancelKeyPress += {
        param($sender, $e)
        $e.Cancel = $true
        Write-Log "Interrupt received, cleaning up..."
        Stop-Container
        exit 0
    }
}

function Start-FileWatcher {
    param([string]$AssemblyFullPath)
    
    Write-Log "DecompilerServer Container File Watcher"
    Write-Log "Runtime: $script:ContainerRuntime"
    Write-Log "Image: $ImageName"
    Write-Log "Assemblies: $AssembliesPath"
    Write-Log "Assembly File: $AssemblyFile"
    Write-Log "Watch Interval: ${WatchInterval}s"
    
    Initialize-Cleanup
    
    # Start initial container
    Start-Container
    $lastHash = Get-FileHash $AssemblyFullPath
    Write-Log "Initial hash: $($lastHash.Substring(0,8))... (watching for changes)"

    # Watch loop
    while ($true) {
        Start-Sleep -Seconds $WatchInterval
        
        if (-not (Test-Path $AssemblyFullPath)) {
            Write-Warning "Assembly file no longer exists: $AssemblyFullPath"
            continue
        }

        $currentHash = Get-FileHash $AssemblyFullPath
        
        if ($currentHash -ne $lastHash) {
            Write-Success "Assembly changed! Hash: $($currentHash.Substring(0,8))..."
            
            # Stop current container
            Stop-Container
            
            # Wait for file operations to complete
            Start-Sleep -Seconds 1
            
            # Start new container
            Start-Container
            $lastHash = $currentHash
            
            Write-Success "Container restarted with fresh assembly"
        } elseif ($Verbose) {
            Write-Log "No changes detected ($($currentHash.Substring(0,8))...)"
        }
    }
}

# Main execution
if ($Help) {
    Show-Usage
    exit 0
}

if (-not $AssembliesPath) {
    Write-Error "AssembliesPath parameter is required"
    Show-Usage
    exit 1
}

try {
    $assemblyFullPath = Test-Configuration
    Start-FileWatcher -AssemblyFullPath $assemblyFullPath
} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    Stop-Container
    exit 1
}