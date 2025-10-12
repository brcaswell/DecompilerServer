# MCP Inspector Integration Configuration

## Overview

This configuration integrates the DecompilerServer with MCP Inspector for real-time debugging and monitoring of MCP operations.

## Prerequisites

1. **Node.js 18+** for MCP Inspector
2. **Docker** for containerized deployment
3. **SeqLog Server** (optional but recommended)

## Setup Instructions

### 1. Install MCP Inspector

```bash
npm install -g @modelcontextprotocol/inspector
```

### 2. Configure Logging

The DecompilerServer is configured with comprehensive logging that works with both SeqLog and MCP Inspector:

#### appsettings.json Configuration
```json
{
  "McpLogging": {
    "LogToolCalls": true,
    "LogAssemblyOperations": true,
    "LogDecompilation": false,
    "LogSearchOperations": true,
    "DetailedErrors": true,
    "LogPerformanceMetrics": true,
    "SlowOperationThresholdMs": 1000,
    "EnableInspector": true,
    "UseCorrelationIds": true
  },
  "SeqLogging": {
    "ServerUrl": "http://localhost:5341",
    "MinimumLevel": "Information"
  }
}
```

### 3. MCP Inspector Configuration

Create `mcp-inspector.config.json`:

```json
{
  "mcpServers": {
    "decompiler-server": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-v", "/path/to/your/assemblies:/app/assemblies:ro",
        "-e", "DECOMPILER_VERBOSE=true",
        "decompiler-server:latest"
      ],
      "env": {
        "DECOMPILER_VERBOSE": "true",
        "McpLogging__EnableInspector": "true",
        "McpLogging__LogToolCalls": "true"
      }
    },
    "decompiler-server-executable": {
      "command": "dotnet",
      "args": ["run", "--project", "/path/to/DecompilerServer", "--verbose"],
      "env": {
        "McpLogging__EnableInspector": "true"
      }
    }
  }
}
```

### 4. Docker Compose with Inspector

```yaml
# docker-compose.inspector.yml
version: '3.8'

services:
  decompiler-server:
    build: .
    environment:
      - DECOMPILER_VERBOSE=true
      - McpLogging__EnableInspector=true
      - McpLogging__LogToolCalls=true
      - Serilog__WriteTo__0__Args__restrictedToMinimumLevel=Debug
    volumes:
      - "./your-assemblies:/app/assemblies:ro"
      - "./logs:/app/logs"
    stdin_open: true
    tty: true

  seq-server:
    image: datalust/seq:latest
    ports:
      - "5341:80"
    environment:
      - ACCEPT_EULA=Y
    volumes:
      - seq-data:/data

  mcp-inspector:
    image: node:18-alpine
    ports:
      - "3000:3000"
    working_dir: /app
    command: npx @modelcontextprotocol/inspector
    volumes:
      - "./mcp-inspector.config.json:/app/config.json"
    depends_on:
      - decompiler-server

volumes:
  seq-data:
```

## Usage Scenarios

### 1. Development with Inspector

```bash
# Start MCP Inspector
mcp-inspector --config mcp-inspector.config.json

# Navigate to http://localhost:3000
# Connect to your DecompilerServer instance
# Monitor real-time MCP tool calls and responses
```

### 2. Production Monitoring with SeqLog

```bash
# Start SeqLog server
docker run -d --name seq -e ACCEPT_EULA=Y -p 5341:80 datalust/seq:latest

# Start DecompilerServer with Seq logging
docker run -d \
  -v "/path/to/assemblies:/app/assemblies:ro" \
  -e "Serilog__WriteTo__2__Args__serverUrl=http://host.docker.internal:5341" \
  decompiler-server:latest
```

### 3. Full Observability Stack

```bash
# Use the Docker Compose configuration
docker-compose -f docker-compose.inspector.yml up -d

# Access:
# - MCP Inspector: http://localhost:3000
# - SeqLog Dashboard: http://localhost:5341
```

## Logging Features

### MCP Tool Call Logging
- **Timing**: All tool calls are timed with millisecond precision
- **Parameters**: Tool parameters are logged at debug level
- **Correlation IDs**: Each request gets a unique 8-character correlation ID
- **Success/Failure**: Clear indication of operation success with error details

### Performance Monitoring
- **Slow Operations**: Operations exceeding threshold (default 1000ms) are highlighted
- **Search Performance**: Query execution times and result counts
- **Decompilation Metrics**: Source generation timing and cache hit rates
- **Assembly Operations**: Loading and context management timing

### Structured Logging
- **JSON Format**: Structured logs compatible with modern log aggregation
- **Enrichment**: Machine name, thread ID, correlation IDs
- **Filtering**: Configurable log levels per component
- **Multiple Sinks**: Console, file, and Seq simultaneously

## Troubleshooting

### Common Issues

1. **Inspector Not Connecting**
   - Ensure MCP server is running and accessible
   - Check that stdin/stdout communication is working
   - Verify environment variables are set correctly

2. **Missing Logs in Seq**
   - Check Seq server URL in configuration
   - Verify network connectivity between containers
   - Ensure log levels are set appropriately

3. **Performance Issues**
   - Adjust `SlowOperationThresholdMs` for your environment
   - Disable verbose logging in production
   - Configure appropriate log retention policies

### Debug Configuration

For maximum debugging information:

```json
{
  "McpLogging": {
    "LogToolCalls": true,
    "LogAssemblyOperations": true,
    "LogDecompilation": true,
    "LogSearchOperations": true,
    "DetailedErrors": true,
    "LogPerformanceMetrics": true,
    "SlowOperationThresholdMs": 100,
    "EnableInspector": true,
    "UseCorrelationIds": true
  }
}
```

## Integration Benefits

1. **Real-time Debugging**: See MCP requests/responses as they happen
2. **Performance Analysis**: Identify slow operations and optimize accordingly
3. **Error Tracking**: Comprehensive error logging with correlation
4. **Operational Insight**: Understand usage patterns and system behavior
5. **Historical Analysis**: Long-term trends and performance metrics in SeqLog