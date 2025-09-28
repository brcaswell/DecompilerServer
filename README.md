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

> **💡 Tip**: See [🤖 AI Tool Integration](#-ai-tool-integration) to configure with AI assistants.

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

### VS Code MCP Integration

Configure DecompilerServer as an MCP server in VS Code using the containerized version:

**Create `.vscode/mcp.json`**:
```json
{
  "inputs": [
    {
      "id": "game-assemblies-path",
      "type": "promptString",
      "description": "Enter the path to your game's Managed assemblies folder (e.g., D:/SteamLibrary/steamapps/common/YourGame/YourGame_Data/Managed)"
    },
    {
      "id": "assembly-filename",
      "type": "promptString", 
      "description": "Enter the assembly filename to analyze",
      "default": "Assembly-CSharp.dll"
    },
    {
      "id": "container-image",
      "type": "promptString",
      "description": "Enter the DecompilerServer container image name",
      "default": "decompiler-server:latest"
    }
  ],
  "servers": {
    "DecompilerServer": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-v",
        "${input:game-assemblies-path}:/app/assemblies:ro",
        "-e",
        "ASSEMBLY_PATH=/app/assemblies/${input:assembly-filename}",
        "${input:container-image}"
      ],
      "env": {
        "GAME_ASSEMBLIES_PATH": "${input:game-assemblies-path}",
        "ASSEMBLY_FILENAME": "${input:assembly-filename}",
        "CONTAINER_IMAGE": "${input:container-image}"
      }
    }
  }
}
```

**For Podman users**, simply change `"command": "docker"` to `"command": "podman"`.

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

### Container Features

- **🔒 Secure**: Read-only volume mounting prevents container from modifying your files
- **🚀 Fast Startup**: Optimized container layers for quick initialization
- **📦 Self-Contained**: No need to install .NET runtime on host system
- **🔄 Stateless**: Each container run is isolated and clean
- **⚖️ Lightweight**: Minimal container footprint with only required dependencies

### Integration with VS Code Copilot Chat

Once configured with `.vscode/mcp.json`, you can use DecompilerServer directly in VS Code Copilot Chat:

```
@DecompilerServer search for MonoBehaviour classes, show me 10 results
@DecompilerServer what namespaces are available in the loaded assembly?
@DecompilerServer decompile the PlayerController class
@DecompilerServer find all methods that use Input.GetKey
```

VS Code will automatically:
1. Prompt you for the assembly path (once per session)
2. Start the containerized DecompilerServer
3. Mount your game/assembly files as read-only volumes
4. Execute your queries and return results
5. Clean up the container after each interaction

## 🤖 AI Tool Integration

Configure with AI assistants via MCP (Model Context Protocol):

**Codex** (`.codex/config.toml`):
```toml
[mcp_servers.decompiler]
command = "path_to_DecompilerServer.exe"
args = []
```

**GitHub Copilot** (`.copilot/config.yaml`):
```yaml
servers:
  decompiler:
    command: "path_to_DecompilerServer.exe"
    args: []
```

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

**VS Code MCP Extension** (`.vscode/settings.json`):
```json
{
  "mcp.servers": [{
    "name": "decompiler",
    "command": "path_to_DecompilerServer.exe",
    "args": []
  }]
}
```

### Basic Usage

1. **Start the server**:
   ```bash
   dotnet run --project DecompilerServer
   ```

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