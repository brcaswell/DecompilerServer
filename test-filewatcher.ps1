#!/usr/bin/env pwsh
# DecompilerServer File Watcher Testing Suite
# Tests file watching capabilities with realistic development scenarios

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("executable", "container", "both")]
    [string]$TestMode = "both",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("FileWatcherTest", "UnityDev")]
    [string]$BuildConfig = "FileWatcherTest",
    
    [Parameter(Mandatory=$false)]
    [int]$TestIterations = 3,
    
    [Parameter(Mandatory=$false)]
    [switch]$SimulateChanges,
    
    [switch]$VerboseOutput,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
DecompilerServer File Watcher Testing Suite

Usage: .\test-filewatcher.ps1 [OPTIONS]

Parameters:
    -TestMode MODE         Test mode: executable, container, or both (default: both)
    -BuildConfig CONFIG    Build configuration: FileWatcherTest or UnityDev (default: FileWatcherTest)
    -TestIterations N      Number of build/watch cycles to test (default: 3)
    -SimulateChanges       Use touch commands instead of real builds for faster testing
    -VerboseOutput         Enable verbose logging
    -Help                  Show this help

Test Scenarios:
    1. Executable Mode: Tests in-process file watching with fast reloads
    2. Container Mode: Tests container restart file watching
    3. Build Simulation: Triggers assembly rebuilds to simulate development

Examples:
    .\test-filewatcher.ps1 -TestMode executable -VerboseOutput
    .\test-filewatcher.ps1 -TestMode container -BuildConfig UnityDev
    .\test-filewatcher.ps1 -TestIterations 5 -SimulateChanges
"@
    exit 0
}

function Write-TestLog([string]$Message, [string]$Color = "White") {
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

function Update-AssemblyFile([string]$AssemblyPath, [bool]$UseTouch) {
    if ($UseTouch) {
        # PowerShell equivalent of 'touch' - update file timestamp
        if (Test-Path $AssemblyPath) {
            (Get-Item $AssemblyPath).LastWriteTime = Get-Date
            Write-TestLog "Touched assembly file (timestamp updated)" "Gray"
        } else {
            Write-TestLog "Assembly file not found for touch: $AssemblyPath" "Red"
        }
    } else {
        # Real build
        dotnet build TestLibrary -c $BuildConfig --no-restore | Out-Null
        Write-TestLog "Real build completed" "Gray"
    }
}

function Test-ExecutableMode {
    Write-TestLog "=== Testing Executable Mode File Watcher ===" "Cyan"
    
    $assemblyDir = if ($BuildConfig -eq "UnityDev") { "unity-assemblies" } else { "test-assemblies" }
    $assemblyPath = "$assemblyDir\net8.0\Assembly-CSharp.dll"
    
    if (-not (Test-Path $assemblyPath)) {
        Write-TestLog "Building initial assembly..." "Yellow"
        dotnet build TestLibrary -c $BuildConfig | Out-Null
    }
    
    Write-TestLog "Starting executable with file watcher..." "Green"
    $env:ENABLE_FILE_WATCHER = "true"
    
    # Start the executable in background
    $process = Start-Process -FilePath "dotnet" -ArgumentList @(
        "run", "--project", "DecompilerServer.csproj", "--", 
        "--file-watcher", "--verbose"
    ) -NoNewWindow -PassThru -RedirectStandardOutput "test-output.log" -RedirectStandardError "test-error.log"
    
    Start-Sleep 2
    
    # Simulate development cycles
    for ($i = 1; $i -le $TestIterations; $i++) {
        $actionType = if ($SimulateChanges) { "Touching" } else { "Rebuilding" }
        Write-TestLog "Iteration ${i}: $actionType assembly..." "Yellow"
        $startTime = Get-Date
        
        # Trigger file change (real build or simulated touch)
        Update-AssemblyFile $assemblyPath $SimulateChanges
        
        $actionTime = (Get-Date) - $startTime
        Write-TestLog "Action completed in $($actionTime.TotalMilliseconds)ms" "Gray"
        
        # Wait for file watcher to detect change
        $waitTime = if ($SimulateChanges) { 1 } else { 2 }
        Start-Sleep $waitTime
    }
    
    # Cleanup
    Start-Sleep 2
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    Write-TestLog "Executable mode test completed" "Green"
}

function Test-ContainerMode {
    Write-TestLog "=== Testing Container Mode File Watcher ===" "Cyan"
    
    # Clean up any existing containers first
    Write-TestLog "Cleaning up existing containers..." "Yellow"
    podman stop decompiler-server -t 1 2>$null | Out-Null
    podman rm decompiler-server 2>$null | Out-Null
    
    $assemblyDir = if ($BuildConfig -eq "UnityDev") { "unity-assemblies" } else { "test-assemblies" }
    $assemblyPath = "$assemblyDir\net8.0"
    
    if (-not (Test-Path "$assemblyPath\Assembly-CSharp.dll")) {
        Write-TestLog "Building initial assembly..." "Yellow"
        dotnet build TestLibrary -c $BuildConfig | Out-Null
    }
    
    Write-TestLog "Starting container file watcher..." "Green"
    
    # Start container watcher in background
    $watcherArgs = @(
        "-AssembliesPath", (Resolve-Path $assemblyPath).Path,
        "-WatchInterval", "1"
    )
    
    if ($VerboseOutput) {
        $watcherArgs += "-VerboseOutput"
    }
    
    $allArgs = @("-ExecutionPolicy", "Bypass", "-File", "scripts\watch-container.ps1") + $watcherArgs
    $watcherProcess = Start-Process -FilePath "PowerShell" -ArgumentList $allArgs -NoNewWindow -PassThru
    
    Write-TestLog "Waiting for container watcher to initialize..." "Gray"
    Start-Sleep 5  # Give more time for container startup
    
    # Check if the watcher process is still running
    if ($watcherProcess.HasExited) {
        Write-TestLog "Container watcher exited unexpectedly (exit code: $($watcherProcess.ExitCode))" "Red"
        return
    }
    
    # Simulate development cycles
    for ($i = 1; $i -le $TestIterations; $i++) {
        $actionType = if ($SimulateChanges) { "Touching" } else { "Rebuilding" }
        Write-TestLog "Iteration ${i}: $actionType assembly (container restart expected)..." "Yellow"
        
        $startTime = Get-Date
        Update-AssemblyFile "$assemblyPath\Assembly-CSharp.dll" $SimulateChanges
        $actionTime = (Get-Date) - $startTime
        
        Write-TestLog "Action completed in $($actionTime.TotalMilliseconds)ms, waiting for container restart..." "Gray"
        # Container restart takes longer, touch is faster
        $waitTime = if ($SimulateChanges) { 3 } else { 4 }
        Start-Sleep $waitTime
    }
    
    # Cleanup with timeout
    Write-TestLog "Cleaning up container watcher..." "Yellow"
    if (-not $watcherProcess.HasExited) {
        Stop-Process -Id $watcherProcess.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep 2
    }
    
    # Clean up any remaining containers
    Write-TestLog "Stopping any remaining containers..." "Gray"
    podman stop decompiler-server -t 2 2>$null | Out-Null
    podman rm decompiler-server 2>$null | Out-Null
    
    Write-TestLog "Container mode test completed" "Green"
}

function Show-TestResults {
    Write-TestLog "=== Test Results Summary ===" "Cyan"
    
    $configs = @{
        "FileWatcherTest" = "Quick iteration testing (minimal features)"
        "UnityDev" = "Unity development simulation (extended features)"
    }
    
    Write-TestLog "Build Configuration: $BuildConfig - $($configs[$BuildConfig])" "White"
    Write-TestLog "Test Iterations: $TestIterations" "White"
    Write-TestLog "Change Method: $(if ($SimulateChanges) { 'Touch commands (fast simulation)' } else { 'Real builds (realistic)' })" "White"
    
    # Show assembly info
    $assemblyDir = if ($BuildConfig -eq "UnityDev") { "unity-assemblies" } else { "test-assemblies" }
    $assemblyPath = "$assemblyDir\net8.0\Assembly-CSharp.dll"
    
    if (Test-Path $assemblyPath) {
        $fileInfo = Get-Item $assemblyPath
        Write-TestLog "Final Assembly: $assemblyPath ($($fileInfo.Length) bytes)" "White"
        Write-TestLog "Last Modified: $($fileInfo.LastWriteTime)" "White"
    }
    
    Write-TestLog "File watcher testing completed!" "Green"
}

# Main execution
Write-TestLog "Starting DecompilerServer File Watcher Tests" "Cyan"
Write-TestLog "Mode: $TestMode | Config: $BuildConfig | Iterations: $TestIterations" "White"

try {
    switch ($TestMode) {
        "executable" { Test-ExecutableMode }
        "container" { Test-ContainerMode }
        "both" { 
            Test-ExecutableMode
            Start-Sleep 2
            Test-ContainerMode
        }
    }
    
    Show-TestResults
} catch {
    Write-TestLog "Test failed: $($_.Exception.Message)" "Red"
    exit 1
}