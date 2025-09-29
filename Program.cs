using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using DecompilerServer.Services;

namespace DecompilerServer;

public partial class Program
{
    public static async Task Main(string[] args)
    {
        // Check for help flag
        if (args.Contains("--help") || args.Contains("-h"))
        {
            ShowHelp();
            return;
        }
        
        // Check for verbose logging flag
        var verbose = args.Contains("--verbose") || args.Contains("-v");
        
        var builder = Host.CreateApplicationBuilder(args);
        builder.Logging.ClearProviders();
        builder.Logging.AddProvider(new StderrLoggerProvider());
        
        // Set log level based on verbose flag
        if (verbose)
        {
            builder.Logging.SetMinimumLevel(LogLevel.Debug);
            // In verbose mode, show all MCP protocol logs
        }
        else
        {
            builder.Logging.SetMinimumLevel(LogLevel.Information);
            // In normal mode, suppress noisy MCP protocol logs
            builder.Logging.AddFilter("Microsoft.Hosting.Lifetime", LogLevel.Warning);
            builder.Logging.AddFilter("ModelContextProtocol", LogLevel.Warning);
        }
        
        builder.Services.AddHostedService<StartupLogService>();

        // Log the startup mode
        if (verbose)
        {
            Console.Error.WriteLine($"STDERR [{DateTime.Now:HH:mm:ss}] DecompilerServer [Information] Starting in verbose mode - MCP protocol details will be logged");
        }

        // Register DecompilerServer services as singletons for state persistence
        builder.Services.AddSingleton<AssemblyContextManager>();
        builder.Services.AddSingleton<MemberResolver>();
        builder.Services.AddSingleton<DecompilerService>();
        builder.Services.AddSingleton<UsageAnalyzer>();
        builder.Services.AddSingleton<InheritanceAnalyzer>();
        builder.Services.AddSingleton<ResponseFormatter>();

        builder.Services
            .AddMcpServer()             // core MCP server services
            .WithStdioServerTransport() // Codex talks to STDIO servers
            .WithToolsFromAssembly();   // auto-discover [McpServerTool]s in this assembly

        var app = builder.Build();

        // Initialize service locator
        ServiceLocator.SetServiceProvider(app.Services);

        await app.RunAsync();
    }

    private static void ShowHelp()
    {
        Console.Error.WriteLine("DecompilerServer - MCP Server for .NET Assembly Analysis");
        Console.Error.WriteLine();
        Console.Error.WriteLine("Usage: DecompilerServer [options]");
        Console.Error.WriteLine();
        Console.Error.WriteLine("Options:");
        Console.Error.WriteLine("  -h, --help      Show this help message");
        Console.Error.WriteLine("  -v, --verbose   Enable verbose logging (shows MCP protocol details)");
        Console.Error.WriteLine();
        Console.Error.WriteLine("The server communicates via stdin/stdout using the Model Context Protocol (MCP).");
        Console.Error.WriteLine("Use this server with AI development tools that support MCP integration.");
        Console.Error.WriteLine();
        Console.Error.WriteLine("Examples:");
        Console.Error.WriteLine("  DecompilerServer                    # Start server with normal logging");
        Console.Error.WriteLine("  DecompilerServer --verbose          # Start server with detailed logging");
        Console.Error.WriteLine("  echo '{\"method\":\"ping\"}' | DecompilerServer  # Test connectivity");
    }
}
