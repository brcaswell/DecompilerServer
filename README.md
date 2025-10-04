# DecompilerServer

A powerful MCP (Model Context Protocol) server for decompiling and analyzing .NET assemblies. DecompilerServer provides comprehensive decompilation, search, and code analysis capabilities for any .NET DLL, with specialized convenience features for Unity's Assembly-CSharp.dll files.

## ✨ Features

- **🔍 Comprehensive Analysis**: 39 specialized MCP tools for deep assembly inspection
- **⚡ High Performance**: Optimized decompilation with intelligent caching and lazy loading  
- **🛠️ Universal Support**: Works with any .NET assembly (.dll, .exe)
- **🎮 Unity-Optimized**: Specialized convenience features for Unity Assembly-CSharp.dll files
- **🔧 Code Generation**: Generate Harmony patches, detour stubs, and extension method wrappers
- **📊 Advanced Search**: Search types, members, attributes, string literals, and usage patterns
- **🧬 Relationship Analysis**: Inheritance tracking, usage analysis, and implementation discovery
- **📝 Source Management**: Line-precise source slicing and batch decompilation
- **🛠️ Developer Tools**: IL analysis, AST outlining, and transpiler target suggestions

## 🚀 Quick Start

### Prerequisites

- .NET 8.0 SDK or later
- Windows, macOS, or Linux

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/pardeike/DecompilerServer.git
   cd DecompilerServer
   ```

2. **Build the project**:
   ```bash
   dotnet build DecompilerServer.sln
   ```

3. **Run tests** (optional):
   ```bash
   dotnet test
   ```

## 📁 Project Structure

```
DecompilerServer/
├── Services/                      # Core service implementations
├── Tools/                         # MCP tool implementations (39 tools)
├── Tests/                         # xUnit test suite
├── TestLibrary/                   # Test assembly for validation
├── Properties/                    # Application properties
├── Program.cs                     # Application entry point
├── ServiceLocator.cs              # Service locator for MCP tools
├── StartupLogService.cs           # Startup logging service
├── StderrLogger.cs                # Custom stderr logger for MCP
├── Dockerfile                     # Container configuration
├── .dockerignore                  # Docker build exclusions
├── compose.yaml                   # Docker Compose configuration
├── compose.debug.yaml             # Docker Compose debug configuration
├── DecompilerServer.sln           # Solution file
└── *.md                           # Documentation files
```



## 🐳 Docker/Podman Support

DecompilerServer provides full containerization support for easy deployment and integration with development workflows.

### Building the Container Image

1. **Build the Docker image**:
   ```bash
   docker build -t decompiler-server:latest .
   ```

   **Or with Podman**:
   ```bash
   podman build -t decompiler-server:latest .
   ```

2. **Verify the build**:
   ```bash
   docker run --rm decompiler-server:latest echo "Container is ready"
   ```



### Container Usage Examples

**Analyze a Unity Game**:
```bash
docker run -i --rm \
  -v "/path/to/YourGame/YourGame_Data/Managed:/app/assemblies:ro" \
  -e "ASSEMBLY_PATH=/app/assemblies/Assembly-CSharp.dll" \
  decompiler-server:latest
```

**Analyze Any .NET Assembly**:
```bash
docker run -i --rm \
  -v "/path/to/your/dlls:/app/assemblies:ro" \
  -e "ASSEMBLY_PATH=/app/assemblies/YourLibrary.dll" \
  decompiler-server:latest
```

**Enable Verbose Logging for Debugging**:
```bash
docker run -i --rm \
  -v "/path/to/your/assemblies:/app/assemblies:ro" \
  -e "ASSEMBLY_PATH=/app/assemblies/Assembly-CSharp.dll" \
  -e "DECOMPILER_VERBOSE=true" \
  decompiler-server:latest
```

### Container Features

- **🔒 Secure**: Read-only volume mounting prevents container from modifying your files
- **🚀 Fast Startup**: Optimized container layers for quick initialization
- **📦 Self-Contained**: No need to install .NET runtime on host system
- **🔄 Stateless**: Each container run is isolated and clean
- **⚖️ Lightweight**: Minimal container footprint with only required dependencies



## 🤖 AI Tool Integration

DecompilerServer supports two deployment modes for MCP (Model Context Protocol) integration:

### 📦 Containerized MCP Server (Recommended)

For isolated, secure analysis with automatic cleanup:

**Claude Desktop** (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "decompiler": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-v", "/path/to/your/assemblies:/app/assemblies:ro",
        "-e", "ASSEMBLY_PATH=/app/assemblies/Assembly-CSharp.dll",
        "decompiler-server:latest"
      ]
    }
  }
}
```

**GitHub Copilot** (`.copilot/config.yaml`):
```yaml
servers:
  decompiler:
    command: "docker"
    args:
      - "run"
      - "-i"
      - "--rm"
      - "-v"
      - "/path/to/your/assemblies:/app/assemblies:ro"
      - "-e"
      - "ASSEMBLY_PATH=/app/assemblies/Assembly-CSharp.dll"
      - "decompiler-server:latest"
```

**Codex** (`.codex/config.toml`):
```toml
[mcp_servers.decompiler]
command = "docker"
args = [
  "run", "-i", "--rm",
  "-v", "/path/to/your/assemblies:/app/assemblies:ro",
  "-e", "ASSEMBLY_PATH=/app/assemblies/Assembly-CSharp.dll",
  "decompiler-server:latest"
]
```

**For Podman users**, simply replace `"docker"` with `"podman"` in the command field.

### 🔧 Direct Executable MCP Server

For development environments with .NET 8.0 installed:

**Claude Desktop** (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "decompiler": {
      "command": "path_to_DecompilerServer.exe",
      "args": []
    }
  }
}
```

**GitHub Copilot** (`.copilot/config.yaml`):
```yaml
servers:
  decompiler:
    command: "path_to_DecompilerServer.exe"
    args: []
```

**Codex** (`.codex/config.toml`):
```toml
[mcp_servers.decompiler]
command = "path_to_DecompilerServer.exe"
args = []
```

### 🎯 Container vs Executable Comparison

| Feature | Containerized | Direct Executable |
|---------|---------------|-------------------|
| **Setup** | Docker/Podman required | .NET 8.0 SDK required |
| **Isolation** | ✅ Complete isolation | ❌ Runs in host environment |
| **Security** | ✅ Read-only volume mounting | ⚠️ Full host access |
| **Dependencies** | ✅ Self-contained | ❌ Requires .NET runtime |
| **Cleanup** | ✅ Automatic via `--rm` | ❌ Manual process management |
| **Performance** | ~5% container overhead | Fastest startup |
| **Portability** | ✅ Works anywhere | OS/architecture dependent |

**Recommendation**: Use containerized deployment for production and secure analysis workflows.

### 🐳 Container Configuration Tips

**Multi-Assembly Support**: Mount multiple directories for complex projects:
```json
{
  "mcpServers": {
    "decompiler": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-v", "/path/to/game/Managed:/app/assemblies:ro",
        "-v", "/path/to/mods:/app/mods:ro",
        "-e", "ASSEMBLY_PATH=/app/assemblies/Assembly-CSharp.dll",
        "decompiler-server:latest"
      ]
    }
  }
}
```

**Debug Mode**: Enable verbose logging for troubleshooting:
```json
{
  "mcpServers": {
    "decompiler": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-v", "/path/to/assemblies:/app/assemblies:ro",
        "-e", "ASSEMBLY_PATH=/app/assemblies/Assembly-CSharp.dll",
        "-e", "DECOMPILER_VERBOSE=true",
        "decompiler-server:latest"
      ]
    }
  }
}
```

**Windows Path Example**: Use Windows-style paths with forward slashes in Docker:
```json
{
  "mcpServers": {
    "decompiler": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-v", "C:/Games/MyGame/MyGame_Data/Managed:/app/assemblies:ro",
        "-e", "ASSEMBLY_PATH=/app/assemblies/Assembly-CSharp.dll",
        "decompiler-server:latest"
      ]
    }
  }
}
```

### 🔄 Environment Variables & Server Lifecycle

**Important**: Environment variable changes require a server restart to take effect.

**For Containerized Deployment**:
- Each container run uses fresh environment variables from the MCP configuration
- No manual restart needed - the `--rm` flag ensures each session starts clean
- To change assembly paths, update your MCP client configuration and restart the AI assistant

**For Direct Executable Deployment**:
- Environment variables are read once at server startup
- Changes to `ASSEMBLY_PATH` or `DECOMPILER_VERBOSE` require stopping and restarting the server process
- Use `Ctrl+C` to stop, then restart with `dotnet run --project DecompilerServer`

**Quick Assembly Switching**: For frequent assembly changes, use the containerized approach with parameterized paths in your MCP client configuration.

### 👁️ File Watching & Auto-Reload

**✅ Now Available**: File watching is implemented with both executable and container-based solutions!

### **Executable Mode File Watching**
Enable automatic assembly reload when files change:

```bash
# Enable file watching with command-line flag (recommended)
DecompilerServer --watch --verbose

# Alternative flag names
DecompilerServer --file-watcher --verbose
DecompilerServer -w --verbose

# Or use environment variable
ENABLE_FILE_WATCHER=true DecompilerServer --verbose

# Windows PowerShell examples
DecompilerServer --watch --verbose
$env:ENABLE_FILE_WATCHER="true"; DecompilerServer --verbose
```

**Features**:
- ✅ **SHA256 hash-based change detection** - ignores metadata-only changes
- ✅ **Debounced file events** - handles multiple rapid changes gracefully  
- ✅ **Automatic assembly context reload** - seamless state refresh
- ✅ **FileSystemWatcher integration** - real-time change notifications

**Important**: File watching is **disabled in container mode** - use container orchestration instead.

### **Container Mode File Watching**

Use the orchestrator scripts for automatic container restart on assembly changes:

#### **Linux/macOS Orchestrator**:
```bash
# Make script executable
chmod +x scripts/watch-container.sh

# Watch Unity assembly with verbose logging
./scripts/watch-container.sh \
  --path "/path/to/Game/Game_Data/Managed" \
  --file "Assembly-CSharp.dll" \
  --verbose

# Watch custom assembly
./scripts/watch-container.sh \
  -p "./assemblies" \
  -f "MyLibrary.dll" \
  -w 1
```

#### **Windows PowerShell Orchestrator**:
```powershell
# Watch Unity assembly
.\scripts\watch-container.ps1 `
  -AssembliesPath "C:\Games\Unity\Game_Data\Managed" `
  -AssemblyFile "Assembly-CSharp.dll" `
  -Verbose

# Watch with custom settings
.\scripts\watch-container.ps1 `
  -AssembliesPath ".\assemblies" `
  -WatchInterval 1 `
  -Verbose
```

#### **Docker Compose File Watching**:
```bash
# Set environment and start
export ASSEMBLIES_PATH="/path/to/Game/Game_Data/Managed"
export ASSEMBLY_FILE="Assembly-CSharp.dll"
export DECOMPILER_VERBOSE="true"

docker-compose -f compose.filewatcher.yaml up
```

### **File Watching Implementation Details**

**Hash-Based Change Detection**:
- Uses **SHA256 hashes** to detect actual content changes
- Ignores timestamp-only modifications
- Debounces rapid successive changes (500ms delay)

**Container Orchestration Strategy**:
- **FileSystemWatcher** monitors assembly directory on host
- **Container restart** triggered on hash change
- **Fresh container state** for each analysis session
- **Graceful cleanup** with proper signal handling

**Performance Characteristics**:
- **Executable mode**: ~50ms reload time for small-medium assemblies
- **Container mode**: ~2-3s restart time (includes container startup)
- **Hash computation**: ~10-100ms depending on assembly size
- **Memory efficient**: No persistent file content caching

**Development Impact**: 
- **Game Development**: Requires server restart after each game build
- **Mod Development**: Manual reload needed when mod assemblies change  
- **CI/CD Pipelines**: Each analysis run should use fresh container instances

### Basic Usage

#### For Containerized Deployment (Recommended)
Configuration is handled entirely through MCP client setup - no manual server startup required. The container starts automatically when your AI assistant connects.

#### For Direct Executable Deployment
1. **Start the server manually**:
   ```bash
   dotnet run --project DecompilerServer
   ```
   
   **Or with verbose logging for debugging**:
   ```bash
   dotnet run --project DecompilerServer -- --verbose
   ```

#### Common MCP Operations (Both Deployment Types)
2. **Load any .NET assembly** (via MCP client):
   ```json
   {
     "tool": "LoadAssembly",
     "arguments": {
       "assemblyPath": "/path/to/YourAssembly.dll"
     }
   }
   ```

   **OR for Unity projects:**
   ```json
   {
     "tool": "LoadAssembly", 
     "arguments": {
       "gameDir": "/path/to/unity/game"
     }
   }
   ```

3. **Explore the assembly**:
   ```json
   {
     "tool": "ListNamespaces",
     "arguments": {}
   }
   ```

4. **Search for types**:
   ```json
   {
     "tool": "SearchTypes", 
     "arguments": {
       "query": "Player",
       "limit": 10
     }
   }
   ```

5. **Decompile source code**:
   ```json
   {
     "tool": "GetDecompiledSource",
     "arguments": {
       "memberId": "<member-id-from-search>"
     }
   }
   ```

## 🏗️ Architecture

DecompilerServer is built on a robust, modular architecture:

### Core Services
- **AssemblyContextManager**: Assembly loading and context management
- **MemberResolver**: Member ID resolution and validation  
- **DecompilerService**: C# decompilation with caching
- **SearchServiceBase**: Search and pagination framework
- **UsageAnalyzer**: Code usage analysis
- **InheritanceAnalyzer**: Inheritance relationship tracking
- **ResponseFormatter**: Standardized JSON response formatting

### MCP Tools (38 endpoints)
- **Core Operations**: Status, LoadAssembly, Unload, WarmIndex
- **Discovery**: ListNamespaces, SearchTypes, SearchMembers, SearchAttributes
- **Analysis**: GetMemberDetails, GetDecompiledSource, GetSourceSlice, GetIL
- **Relationships**: FindUsages, FindCallers, FindCallees, GetOverrides
- **Code Generation**: GenerateHarmonyPatchSkeleton, GenerateDetourStub
- **Advanced**: BatchGetDecompiledSource, SuggestTranspilerTargets, PlanChunking

### Member ID System
All members use a stable ID format: `<mvid-32hex>:<token-8hex>:<kind-code>`
- **Kind Codes**: T=Type, M=Method/Constructor, P=Property, F=Field, E=Event, N=Namespace
- IDs remain consistent across sessions for reliable automation

## 📖 Examples

### Analyzing Any .NET Assembly

```bash
# 1. Load any .NET assembly directly
{
  "tool": "LoadAssembly",
  "arguments": {
    "assemblyPath": "/path/to/MyLibrary.dll"
  }
}

# 2. Find all public classes
{
  "tool": "SearchTypes",
  "arguments": {
    "query": "",
    "accessibility": "public"
  }
}

# 3. Get detailed information about a specific type
{
  "tool": "GetMemberDetails", 
  "arguments": {
    "memberId": "abc123...def:12345678:T"
  }
}
```

### Analyzing a Unity Assembly

```bash
# 1. Load Unity's main assembly
{
  "tool": "LoadAssembly",
  "arguments": {
    "assemblyPath": "Game_Data/Managed/Assembly-CSharp.dll"
  }
}

# 2. Find all Player-related classes
{
  "tool": "SearchTypes",
  "arguments": {
    "query": "Player",
    "accessibility": "public"
  }
}

# 3. Get detailed information about a specific type
{
  "tool": "GetMemberDetails", 
  "arguments": {
    "memberId": "abc123...def:12345678:T"
  }
}

# 4. Generate a Harmony patch skeleton
{
  "tool": "GenerateHarmonyPatchSkeleton",
  "arguments": {
    "memberId": "abc123...def:87654321:M",
    "patchType": "Prefix"
  }
}
```

### Batch Analysis Workflow

```bash
# 1. Search for methods containing specific string literals
{
  "tool": "SearchStringLiterals",
  "arguments": {
    "query": "PlayerDied",
    "caseSensitive": false
  }
}

# 2. Batch decompile multiple members
{
  "tool": "BatchGetDecompiledSource",
  "arguments": {
    "memberIds": ["id1", "id2", "id3"]
  }
}

# 3. Analyze usage patterns
{
  "tool": "FindUsages",
  "arguments": {
    "memberId": "target-member-id",
    "includeReferences": true
  }
}
```

## 🔧 Development

### Building

```bash
# Build entire solution
dotnet build DecompilerServer.sln

# Build specific project
dotnet build DecompilerServer.csproj
```

### Testing

```bash
# Run all tests
dotnet test

# Run with verbose output
dotnet test --verbosity normal

# Run specific test class
dotnet test --filter "ClassName=CoreToolTests"
```

### Code Formatting

```bash
# Format code before committing
dotnet format DecompilerServer.sln
```

### Project Structure

```
DecompilerServer/
├── Services/           # Core service implementations (7 services)
├── Tools/             # MCP tool implementations (39 tools)  
├── Tests/             # Comprehensive xUnit test suite
├── TestLibrary/       # Test assembly for validation
├── Program.cs         # Application entry point
├── ServiceLocator.cs  # Service locator for MCP tools
└── *.md              # Documentation files
```

## 📚 Documentation

- **[HELPER_METHODS_GUIDE.md](HELPER_METHODS_GUIDE.md)** - Comprehensive guide to service helpers and implementation patterns
- **[TESTING.md](TESTING.md)** - Complete testing framework documentation and best practices  
- **[TODO.md](TODO.md)** - Prioritized enhancement opportunities and development roadmap
- **[.github/copilot-instructions.md](.github/copilot-instructions.md)** - Detailed project architecture and AI development guidelines

## 🤝 Contributing

We welcome contributions! Please see our development documentation for detailed guidelines:

1. **Read the documentation**: Start with [HELPER_METHODS_GUIDE.md](HELPER_METHODS_GUIDE.md) and [TESTING.md](TESTING.md)
2. **Check the roadmap**: Review [TODO.md](TODO.md) for priority items
3. **Follow patterns**: Study existing tools and services for consistency
4. **Test thoroughly**: Use the comprehensive xUnit framework
5. **Format code**: Run `dotnet format` before committing

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes following existing patterns
4. Add tests for new functionality
5. Run `dotnet test` to ensure all tests pass
6. Run `dotnet format` to maintain code style
7. Submit a pull request with a clear description

## 🛡️ Thread Safety & Performance

DecompilerServer is designed for high performance and thread safety:

- **Thread-Safe Access**: Uses `ReaderWriterLockSlim` for concurrent operations
- **Intelligent Caching**: Decompiled source with line indexing for efficient slicing
- **Lazy Loading**: Minimal upfront computation, build indexes on demand
- **Pagination**: All search results paginated (default: 50, max: 500 items)

## 🔌 MCP Integration

DecompilerServer implements the Model Context Protocol for seamless integration with AI development tools:

- **Auto-Discovery**: Tools automatically discovered via `[McpServerTool]` attributes
- **Standardized Responses**: Consistent JSON formatting across all endpoints
- **Error Handling**: Structured error responses with detailed messages
- **Type Safety**: Strong typing for all tool parameters and responses

See [🤖 AI Tool Integration](#-ai-tool-integration) for configuration examples.

## 📋 System Requirements

- **.NET 8.0** or later
- **Memory**: Recommended 4GB+ for large assemblies
- **Storage**: Varies by assembly size (caching may require additional space)
- **Platform**: Windows, macOS, or Linux

## 📜 License

This project is open source. Please check the repository for license details.

## 🙏 Acknowledgments

Built with:
- **[ICSharpCode.Decompiler](https://github.com/icsharpcode/ILSpy)** - Core decompilation engine
- **[ModelContextProtocol](https://github.com/microsoft/model-context-protocol)** - MCP server framework
- **Microsoft.Extensions.Hosting** - Application hosting and dependency injection

---

*For detailed technical documentation and advanced usage scenarios, please refer to the comprehensive guides in the repository documentation.*