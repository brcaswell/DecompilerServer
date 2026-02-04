# MCP Logging Test Script
Write-Host "Testing MCP Server Logging Integration" -ForegroundColor Green

# Check if Seq server is running
Write-Host "1. Checking Seq server status..." -ForegroundColor Yellow
$seqStatus = docker ps --filter name=decompiler-seq --format "{{.Names}}"
if ($seqStatus -match "decompiler-seq") {
    Write-Host "Seq server is running" -ForegroundColor Green
    Write-Host "Access Seq at: http://localhost:5342" -ForegroundColor Cyan
} else {
    Write-Host "Seq server is not running" -ForegroundColor Red
    Write-Host "Start it with: docker-compose -f compose.logging.yaml up -d" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "2. Testing MCP server..." -ForegroundColor Yellow

# Test MCP server with proper stdin handling
# Use -a stdin to attach and keep stdin open, and use cat to ensure proper piping
$request = '{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "mcp_decompilerser_ping", "arguments": {}}}'
Write-Output $request | docker run -i --rm --network decompilerserver_mcp-logging-network -e McpLogging__LogToolCalls=true -e McpLogging__UseCorrelationIds=true localhost/decompiler-mcp-server:dev

Write-Host ""
Write-Host "Check logs in Seq at: http://localhost:5342" -ForegroundColor Cyan