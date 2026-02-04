using Microsoft.Extensions.Logging;
using System.Diagnostics;
using System.Runtime.CompilerServices;

namespace DecompilerServer.Services;

/// <summary>
/// Configuration options for MCP-specific logging behaviors
/// </summary>
public class McpLoggingOptions
{
    public const string SectionName = "McpLogging";

    /// <summary>
    /// Enable detailed logging of MCP tool calls with parameters and timing
    /// </summary>
    public bool LogToolCalls { get; set; } = true;

    /// <summary>
    /// Log assembly loading, unloading, and context operations
    /// </summary>
    public bool LogAssemblyOperations { get; set; } = true;

    /// <summary>
    /// Log decompilation operations with timing and caching information
    /// </summary>
    public bool LogDecompilation { get; set; } = false;

    /// <summary>
    /// Log search operations with query details and result counts
    /// </summary>
    public bool LogSearchOperations { get; set; } = true;

    /// <summary>
    /// Include detailed error information and stack traces
    /// </summary>
    public bool DetailedErrors { get; set; } = true;

    /// <summary>
    /// Log performance metrics and slow operations
    /// </summary>
    public bool LogPerformanceMetrics { get; set; } = true;

    /// <summary>
    /// Threshold in milliseconds for logging slow operations
    /// </summary>
    public int SlowOperationThresholdMs { get; set; } = 1000;

    /// <summary>
    /// Enable MCP Inspector integration logging
    /// </summary>
    public bool EnableInspector { get; set; } = true;

    /// <summary>
    /// Log correlation IDs for request tracing
    /// </summary>
    public bool UseCorrelationIds { get; set; } = true;
}

/// <summary>
/// Specialized logging service for MCP server operations and diagnostics
/// </summary>
public class McpLoggingService
{
    private readonly ILogger<McpLoggingService> _logger;
    private readonly McpLoggingOptions _options;
    private static readonly ActivitySource ActivitySource = new("DecompilerServer.MCP");

    public McpLoggingService(ILogger<McpLoggingService> logger, McpLoggingOptions options)
    {
        _logger = logger;
        _options = options;
    }

    /// <summary>
    /// Log MCP tool call execution with timing and result information
    /// </summary>
    public void LogToolCall(string toolName, object? parameters, TimeSpan duration, bool success, string? error = null, [CallerMemberName] string? caller = null)
    {
        if (!_options.LogToolCalls) return;

        using var activity = ActivitySource.StartActivity($"MCP.Tool.{toolName}");
        
        var correlationId = _options.UseCorrelationIds ? Guid.NewGuid().ToString("N")[..8] : null;
        
        if (correlationId != null)
        {
            activity?.SetTag("correlation_id", correlationId);
        }

        var logLevel = success ? LogLevel.Information : LogLevel.Error;
        var durationMs = duration.TotalMilliseconds;

        if (success)
        {
            if (durationMs > _options.SlowOperationThresholdMs && _options.LogPerformanceMetrics)
            {
                _logger.LogWarning(
                    "[{CorrelationId}] SLOW MCP Tool: {ToolName} completed in {DurationMs:F1}ms (called from {Caller})",
                    correlationId, toolName, durationMs, caller);
            }
            else
            {
                _logger.LogInformation(
                    "[{CorrelationId}] MCP Tool: {ToolName} completed in {DurationMs:F1}ms - Success: {Success}",
                    correlationId, toolName, durationMs, success);
            }
        }
        else
        {
            if (_options.DetailedErrors)
            {
                _logger.LogError(
                    "[{CorrelationId}] MCP Tool: {ToolName} FAILED in {DurationMs:F1}ms - Error: {Error} (called from {Caller})",
                    correlationId, toolName, durationMs, error, caller);
            }
            else
            {
                _logger.LogError(
                    "[{CorrelationId}] MCP Tool: {ToolName} FAILED in {DurationMs:F1}ms",
                    correlationId, toolName, durationMs);
            }
        }

        // Log parameters at debug level
        if (parameters != null)
        {
            _logger.LogDebug(
                "[{CorrelationId}] MCP Tool Parameters: {ToolName} - {Parameters}",
                correlationId, toolName, parameters);
        }
    }

    /// <summary>
    /// Log assembly loading and context management operations
    /// </summary>
    public void LogAssemblyOperation(string operation, string? assemblyPath, bool success, TimeSpan? duration = null, string? details = null)
    {
        if (!_options.LogAssemblyOperations) return;

        using var activity = ActivitySource.StartActivity($"MCP.Assembly.{operation}");
        var correlationId = _options.UseCorrelationIds ? Guid.NewGuid().ToString("N")[..8] : null;

        if (correlationId != null)
        {
            activity?.SetTag("correlation_id", correlationId);
            activity?.SetTag("assembly_path", assemblyPath);
            activity?.SetTag("operation", operation);
        }

        var logLevel = success ? LogLevel.Information : LogLevel.Warning;
        var message = duration.HasValue 
            ? "[{CorrelationId}] Assembly Operation: {Operation} on {AssemblyPath} - Success: {Success} ({DurationMs:F1}ms)"
            : "[{CorrelationId}] Assembly Operation: {Operation} on {AssemblyPath} - Success: {Success}";

        if (duration.HasValue)
        {
            _logger.Log(logLevel, message, correlationId, operation, assemblyPath ?? "unknown", success, duration.Value.TotalMilliseconds);
        }
        else
        {
            _logger.Log(logLevel, message, correlationId, operation, assemblyPath ?? "unknown", success);
        }

        if (details != null)
        {
            _logger.LogDebug("[{CorrelationId}] Assembly Operation Details: {Details}", correlationId, details);
        }
    }

    /// <summary>
    /// Log decompilation operations with performance metrics
    /// </summary>
    public void LogDecompilation(string memberId, int lineCount, TimeSpan duration, bool fromCache, string? sourceType = null)
    {
        if (!_options.LogDecompilation) return;

        using var activity = ActivitySource.StartActivity("MCP.Decompilation");
        var correlationId = _options.UseCorrelationIds ? Guid.NewGuid().ToString("N")[..8] : null;

        if (correlationId != null)
        {
            activity?.SetTag("correlation_id", correlationId);
            activity?.SetTag("member_id", memberId);
            activity?.SetTag("from_cache", fromCache);
        }

        var durationMs = duration.TotalMilliseconds;
        var cacheStatus = fromCache ? "cached" : "fresh";
        var typeInfo = sourceType != null ? $" ({sourceType})" : "";

        if (_options.LogPerformanceMetrics && durationMs > _options.SlowOperationThresholdMs)
        {
            _logger.LogWarning(
                "[{CorrelationId}] SLOW Decompilation{TypeInfo}: {MemberId} produced {LineCount} lines in {DurationMs:F1}ms ({CacheStatus})",
                correlationId, typeInfo, memberId, lineCount, durationMs, cacheStatus);
        }
        else
        {
            _logger.LogDebug(
                "[{CorrelationId}] Decompilation{TypeInfo}: {MemberId} produced {LineCount} lines in {DurationMs:F1}ms ({CacheStatus})",
                correlationId, typeInfo, memberId, lineCount, durationMs, cacheStatus);
        }
    }

    /// <summary>
    /// Log search operations with query details and performance metrics
    /// </summary>
    public void LogSearchOperation(string searchType, string query, int resultCount, TimeSpan duration, string? filterInfo = null)
    {
        if (!_options.LogSearchOperations) return;

        using var activity = ActivitySource.StartActivity($"MCP.Search.{searchType}");
        var correlationId = _options.UseCorrelationIds ? Guid.NewGuid().ToString("N")[..8] : null;

        if (correlationId != null)
        {
            activity?.SetTag("correlation_id", correlationId);
            activity?.SetTag("search_type", searchType);
            activity?.SetTag("result_count", resultCount);
        }

        var durationMs = duration.TotalMilliseconds;
        var filterText = filterInfo != null ? $" (filters: {filterInfo})" : "";

        if (_options.LogPerformanceMetrics && durationMs > _options.SlowOperationThresholdMs)
        {
            _logger.LogWarning(
                "[{CorrelationId}] SLOW Search: {SearchType} for '{Query}'{FilterText} returned {ResultCount} results in {DurationMs:F1}ms",
                correlationId, searchType, query, filterText, resultCount, durationMs);
        }
        else
        {
            _logger.LogInformation(
                "[{CorrelationId}] Search: {SearchType} for '{Query}'{FilterText} returned {ResultCount} results in {DurationMs:F1}ms",
                correlationId, searchType, query, filterText, resultCount, durationMs);
        }
    }

    /// <summary>
    /// Log error conditions with optional correlation context
    /// </summary>
    public void LogError(Exception exception, string context, string? correlationId = null)
    {
        using var activity = ActivitySource.StartActivity("MCP.Error");
        correlationId ??= _options.UseCorrelationIds ? Guid.NewGuid().ToString("N")[..8] : null;

        if (correlationId != null)
        {
            activity?.SetTag("correlation_id", correlationId);
        }

        if (_options.DetailedErrors)
        {
            _logger.LogError(exception,
                "[{CorrelationId}] MCP Error in {Context}: {Message}",
                correlationId, context, exception.Message);
        }
        else
        {
            _logger.LogError(
                "[{CorrelationId}] MCP Error in {Context}: {Message}",
                correlationId, context, exception.Message);
        }
    }

    /// <summary>
    /// Create a correlation ID for request tracking
    /// </summary>
    public string CreateCorrelationId()
    {
        return _options.UseCorrelationIds ? Guid.NewGuid().ToString("N")[..8] : string.Empty;
    }

    /// <summary>
    /// Log MCP Inspector events if enabled
    /// </summary>
    public void LogInspectorEvent(string eventType, object? data = null)
    {
        if (!_options.EnableInspector) return;

        _logger.LogDebug("MCP Inspector Event: {EventType} - {Data}", eventType, data);
    }
}