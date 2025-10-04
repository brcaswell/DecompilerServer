# DecompilerServer Container File Watcher for Windows
# Monitors assembly files and restarts container when changes are detected

param(
    [Parameter(Mandatory=$true)]
    [string]$AssembliesPath,
    
    [string]$AssemblyFile = "Assembly-CSharp.dll",
    [string]$ContainerName = "decompiler-server",
    [string]$ImageName = "localhost/decompiler-server:latest",
    [switch]$VerboseOutput,
    [int]$WatchInterval = 1,
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
    -ImageName IMAGE        Container image (default: localhost/decompiler-server:latest)
    -VerboseOutput         Enable verbose logging
    -WatchInterval N       Watch interval in seconds (default: 1)
    -Help                  Show this help

Examples:
    .\watch-container.ps1 -AssembliesPath "C:\Games\Unity\Managed"
    .\watch-container.ps1 -AssembliesPath ".\assemblies" -VerboseOutput
    .\watch-container.ps1 -AssembliesPath "C:\Games\Managed" -WatchInterval 1 -VerboseOutput

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

    # Verify container image exists
    try {
        $imageCheck = & $script:ContainerRuntime images --format "{{.Repository}}:{{.Tag}}" 2>$null | Where-Object { $_ -eq $ImageName }
        if (-not $imageCheck) {
            Write-Error "Container image not found: $ImageName"
            Write-Host "Available images:" -ForegroundColor Yellow
            & $script:ContainerRuntime images
            exit 1
        }
    } catch {
        Write-Warning "Could not verify image existence, proceeding anyway"
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
    # Clean up any existing containers with the same name
    Write-Log "Cleaning up existing containers..."
    & $script:ContainerRuntime stop $ContainerName -t 1 2>$null | Out-Null
    & $script:ContainerRuntime rm $ContainerName 2>$null | Out-Null
    
    Write-Log "Starting DecompilerServer container..."
    
    $dockerArgs = @(
        "run"
        "--name", $ContainerName
        "--rm"
        "-i"
        "-v", "${AssembliesPath}:/app/assemblies:ro"
        "-e", "ASSEMBLY_PATH=/app/assemblies/$AssemblyFile"
    )
    
    if ($VerboseOutput) {
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

    # Handle Ctrl+C (with error handling for different PowerShell environments)
    try {
        [Console]::TreatControlCAsInput = $false
        [Console]::CancelKeyPress += {
            param($sender, $e)
            $e.Cancel = $true
            Write-Log "Interrupt received, cleaning up..."
            Stop-Container
            exit 0
        }
    } catch {
        Write-Log "Console event handling not available in this environment" "Yellow"
        # Continue without Ctrl+C handling
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
    Write-Log "Initial hash: $($lastHash.Hash.Substring(0,8))... (watching for changes)"

    # Watch loop
    $script:CheckCount = 0
    while ($true) {
        Start-Sleep -Seconds $WatchInterval
        $script:CheckCount++
        
        if (-not (Test-Path $AssemblyFullPath)) {
            Write-Warning "Assembly file no longer exists: $AssemblyFullPath"
            continue
        }

        $currentHash = Get-FileHash $AssemblyFullPath
        
        if ($currentHash.Hash -ne $lastHash.Hash) {
            Write-Success "Assembly changed! Hash: $($currentHash.Hash.Substring(0,8))..."
            
            # Stop current container
            Stop-Container
            
            # Wait for file operations to complete
            Start-Sleep -Seconds 1
            
            # Start new container
            Start-Container
            $lastHash = $currentHash
            
            Write-Success "Container restarted with fresh assembly"
        } elseif ($VerboseOutput) {
            # Only log every 10th check to reduce noise
            if ($script:CheckCount % 10 -eq 0) {
                Write-Log "Status: Monitoring... ($($currentHash.Hash.Substring(0,8))...)"
            }
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