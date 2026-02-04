# MCP Server Troubleshooting Guide

## Issue: "ModelService: Cannot add model because it already exists!"

### Symptom
When attempting to use MCP decompiler tools in VS Code, the following error occurs:
```
Failed to render content: ModelService: Cannot add model because it already exists!
```

### Root Cause
This error indicates a **client-side state management issue** in VS Code's MCP (Model Context Protocol) implementation, not a container or server-side problem.

**What's happening:**
- VS Code/GitHub Copilot maintains stateful information about registered MCP servers
- When the MCP server is reconfigured or restarted, VS Code attempts to re-register the server model
- The MCP client doesn't properly clean up the old registration before adding the new one
- This results in a duplicate model registration conflict

### Key Observations
- **Not a container conflict**: Multiple containers with different names/images don't cause this issue
- **Client-side problem**: The error originates from VS Code's MCP client, not the server
- **State persistence**: VS Code caches MCP server registrations across sessions

### Solutions (in order of preference)

#### 1. Reload VS Code Window
**Recommended first step:**
- Press `Ctrl+Shift+P`
- Type "Developer: Reload Window"
- This clears the MCP client state without fully restarting VS Code

#### 2. Restart VS Code Completely
If window reload doesn't work:
- Close VS Code entirely
- Restart the application
- This performs a full cleanup of extension host state

#### 3. Check MCP Configuration
Verify `.vscode/mcp.json` doesn't have duplicate server entries:
```json
{
  "servers": {
    "DecompilerServer": {
      // Only one server with this name should exist
    }
  }
}
```

#### 4. Clear VS Code Extension Host Cache
If the issue persists:
- Close VS Code
- Delete VS Code workspace cache (varies by OS)
- Restart VS Code

### Prevention
- Avoid running multiple VS Code instances with the same MCP configuration
- When modifying MCP server configuration, reload the window before testing
- Use unique server names if testing multiple configurations

### Environment Details
- **Date Encountered**: September 28, 2025
- **VS Code Version**: Latest (check Help → About)
- **MCP Protocol**: Model Context Protocol via GitHub Copilot
- **Server Type**: DecompilerServer (containerized .NET MCP server)
- **Container Runtime**: Both Docker and Podman tested (not the cause)

### Related Files
- `.vscode/mcp.json` - MCP server configuration
- `Dockerfile` - Container configuration
- `README.md` - Usage instructions
- This troubleshooting guide

### Status
**Resolution Attempted**: VS Code window reload
**Next Steps**: Document results and update this guide based on outcome

---

## Issue: Container File Watcher with Podman

### Symptom
When using the container file watcher (`scripts/watch-container.ps1`), you may encounter:
- "Container image not found" errors
- Container startup failures
- Hanging scripts with no visible containers running
- Image name mismatches between build and runtime

### Root Cause: Podman Image Naming Convention
**Podman automatically prefixes image names with `localhost/`** during the build process, while Docker does not.

**Example:**
```bash
# Build command (same for both)
podman build -t decompiler-server:latest .

# Resulting image name
Docker: decompiler-server:latest
Podman: localhost/decompiler-server:latest
```

### Solutions

#### 1. Use Correct Image Name (Recommended)
The container watcher script now auto-detects and uses the correct image name:
```powershell
# Default parameter value is now:
-ImageName "localhost/decompiler-server:latest"
```

#### 2. Manual Image Name Override
If using a different image name:
```powershell
.\scripts\watch-container.ps1 -AssembliesPath "C:\path\to\assemblies" -ImageName "your-custom-image:tag"
```

#### 3. Image Verification
The script now verifies the image exists before attempting to start containers:
```powershell
# This will show available images if the specified one is not found
podman images
```

### Debugging Container Issues

#### Check Available Images
```powershell
podman images | Select-String "decompiler"
```

#### Test Container Manually
```powershell
podman run --name test-decompiler --rm -i \
  -v "C:\path\to\assemblies:/app/assemblies:ro" \
  -e "ASSEMBLY_PATH=/app/assemblies/Assembly-CSharp.dll" \
  localhost/decompiler-server:latest
```

#### Monitor Container Status
```powershell
# Check running containers
podman ps

# Check all containers (including stopped)
podman ps -a
```

### File Watcher Optimization for AI Development

#### Polling Rate Considerations
- **Default**: 5-second intervals (optimized for AI-assisted development)
- **Fast Testing**: Use `-SimulateChanges` flag with touch commands
- **Production**: Use real builds for accurate testing

#### Verbose Output Control
```powershell
# Minimal output (recommended for background operation)
.\scripts\watch-container.ps1 -AssembliesPath "path"

# Verbose output (for debugging)
.\scripts\watch-container.ps1 -AssembliesPath "path" -VerboseOutput
```

#### Touch Simulation vs Real Builds
```powershell
# Fast testing with file timestamp updates (recommended for iteration)
.\test-filewatcher.ps1 -TestMode executable -SimulateChanges

# Realistic testing with actual builds
.\test-filewatcher.ps1 -TestMode container -BuildConfig UnityDev
```

### Container vs Executable Mode Trade-offs

| Mode | Reload Time | Use Case | Pros | Cons |
|------|-------------|----------|------|------|
| **Executable** | ~50ms | Development | Fast iteration, simple debugging | Single process, no isolation |
| **Container** | ~2-3s | Production-like | Process isolation, realistic deployment | Slower, more complex setup |

### Prevention Tips
1. **Always use `localhost/` prefix with Podman-built images**
2. **Test container startup manually before using file watcher**
3. **Use executable mode for rapid AI-assisted development**
4. **Reserve container mode for production-like testing**
5. **Clean up containers between test runs**: `podman stop decompiler-server; podman rm decompiler-server`

### Quick Reference Commands

#### Build and Test Sequence
```powershell
# 1. Build the container image
podman build -t decompiler-server:latest .

# 2. Test executable mode (fast iteration)
.\test-filewatcher.ps1 -TestMode executable -SimulateChanges -VerboseOutput

# 3. Test container mode (realistic)
.\test-filewatcher.ps1 -TestMode container -TestIterations 1

# 4. Manual container watcher
.\scripts\watch-container.ps1 -AssembliesPath ".\test-assemblies\net8.0" -VerboseOutput
```

#### Troubleshooting Commands
```powershell
# Check Podman image name
podman images | findstr decompiler

# Clean up containers
podman stop decompiler-server -t 2; podman rm decompiler-server

# Test container manually
podman run --rm -i --name test localhost/decompiler-server:latest

# Check file watcher logs
Get-Content test-error.log -Tail 10
```

### Environment Details
- **Container Runtime**: Podman 5.6.0+ (primary), Docker 28.4.0+ (fallback)
- **Image Naming**: `localhost/decompiler-server:latest` (Podman), `decompiler-server:latest` (Docker)
- **File Watcher**: Hash-based change detection with configurable polling
- **Testing Framework**: PowerShell scripts with touch simulation support

---

## MCP Logging and Seq Integration

### Issue: Logs Not Appearing in Seq UI

#### Symptoms
- MCP server runs successfully
- Tools execute without errors
- No logs visible at http://localhost:5342

#### Common Causes & Solutions

**1. Seq Server Not Running**
```powershell
# Check if Seq container is running
docker ps --filter name=decompiler-seq

# If not running, start it
docker-compose -f compose.logging.yaml up -d

# Verify Seq is accessible
curl http://localhost:5342/api/events/raw
```

**2. MCP Server Not on Logging Network**
```powershell
# Check networks
docker network ls | grep mcp-logging

# Verify MCP server container is on the network
# In mcp.json, ensure --network flag is present:
"args": [
  "run", "-i", "--rm",
  "--network", "decompilerserver_mcp-logging-network",
  ...
]
```

**3. Console Sink Writing to Stdout (MCP Protocol Interference)**
- **Problem**: MCP protocol uses stdout for JSON-RPC messages
- **Solution**: Console sink must write to stderr

Check `appsettings.json`:
```json
{
  "Name": "Console",
  "Args": {
    "standardErrorFromLevel": "Verbose"  // ← This is critical
  }
}
```

**4. Container Exiting Before Logs Flush**
- **Problem**: Short-lived containers exit before async Seq sink sends logs
- **Solution**: Added 1-second delay in finally block

Check `Program.cs`:
```csharp
finally
{
    Log.Information("MCP Server shutting down");
    await Task.Delay(1000); // Give time for logs to send
    await Log.CloseAndFlushAsync();
}
```

**5. Seq Batching Configuration**
Default batching is too slow for short-lived containers.

Check `appsettings.json`:
```json
{
  "Name": "Seq",
  "Args": {
    "serverUrl": "http://decompiler-seq:80",
    "batchPostingLimit": 1,      // Send immediately
    "period": "00:00:00.5"       // Check every 0.5 seconds
  }
}
```

### Issue: Console Warnings in MCP Output Panel

#### Symptom
```
[warning] Failed to parse message: "[04:11:21 INF] : DecompilerServer starting up"
```

#### Cause
Console sink was writing to stdout instead of stderr, interfering with MCP's JSON-RPC protocol.

#### Solution
Configure Console sink to write all levels to stderr:
```json
{
  "Name": "Console",
  "Args": {
    "standardErrorFromLevel": "Verbose",
    "outputTemplate": "[{Timestamp:HH:mm:ss} {Level:u3}] {SourceContext:l}: {Message:lj}{NewLine}{Exception}"
  }
}
```

### Issue: appsettings.json Not Included in Docker Image

#### Symptom
- MCP server runs but has no Seq configuration
- Logs only appear in console, not in Seq

#### Cause
`dotnet publish` doesn't include `appsettings.json` by default.

#### Solution
Add to `DecompilerServer.csproj`:
```xml
<ItemGroup>
  <Content Include="appsettings.json">
    <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    <CopyToPublishDirectory>PreserveNewest</CopyToPublishDirectory>
  </Content>
  <Content Include="appsettings.Development.json">
    <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    <CopyToPublishDirectory>PreserveNewest</CopyToPublishDirectory>
  </Content>
</ItemGroup>
```

### Issue: Seq Shows No POST Requests

#### Symptom
- Seq container logs show only GET requests (UI polling)
- No `/api/events/raw` POST requests visible

#### Debugging Steps

**1. Test Seq Directly**
```powershell
# From host
Invoke-WebRequest -Uri 'http://localhost:5342/api/events/raw?clef' `
  -Method POST `
  -Body '{"@t":"2026-02-03T10:30:00Z","@m":"Test","Level":"Information"}' `
  -ContentType 'application/vnd.serilog.clef'

# Should return: StatusCode 201 Created
```

**2. Test from Docker Network**
```bash
# Create test script
cat > test-seq-network.sh <<'EOF'
#!/bin/sh
curl -X POST 'http://decompiler-seq:80/api/events/raw?clef' \
  -H 'Content-Type: application/vnd.serilog.clef' \
  -d '{"@t":"2026-02-03T10:40:00Z","@m":"Test from Docker network","Level":"Information"}'
EOF

# Run from container on same network
docker run -i --rm --network decompilerserver_mcp-logging-network \
  -v ${PWD}/test-seq-network.sh:/test.sh \
  curlimages/curl:latest sh /test.sh
```

**3. Enable Serilog Self-Diagnostics**
Add to `Program.cs` before creating LoggerConfiguration:
```csharp
Serilog.Debugging.SelfLog.Enable(msg => Console.Error.WriteLine($"SERILOG DEBUG: {msg}"));
```

This will reveal if Serilog is having issues connecting to Seq.

### Testing Logging Integration

Use the included test script:
```powershell
.\test-mcp-logging.ps1
```

**Expected behavior:**
1. Verifies Seq is running
2. Runs MCP ping test
3. Logs appear in Seq UI at http://localhost:5342

**Check logs in Seq:**
- Filter: `Application = "DecompilerServer"`
- Look for: Startup logs, tool calls, performance metrics
- Verify: Correlation IDs, timestamps, structured properties

### Seq UI Access

**URL**: http://localhost:5342
**Default credentials**: No authentication (configured with `SEQ_FIRSTRUN_NOAUTHENTICATION=true`)

**Useful Seq queries:**
```
# All DecompilerServer logs
Application = "DecompilerServer"

# Tool calls only
ToolName <> null

# Errors and warnings
@Level = "Error" OR @Level = "Warning"

# Slow operations (>1 second)
ElapsedMs > 1000

# Specific correlation
CorrelationId = "your-correlation-id"
```