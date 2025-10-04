using System.Security.Cryptography;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace DecompilerServer.Services;

/// <summary>
/// Monitors assembly files for changes and triggers container restart or reload
/// </summary>
public class FileWatcherService : BackgroundService
{
    private readonly ILogger<FileWatcherService> _logger;
    private readonly AssemblyContextManager _contextManager;
    private FileSystemWatcher? _watcher;
    private readonly Dictionary<string, string> _fileHashes = new();
    private readonly SemaphoreSlim _reloadSemaphore = new(1, 1);

    public FileWatcherService(ILogger<FileWatcherService> logger, AssemblyContextManager contextManager)
    {
        _logger = logger;
        _contextManager = contextManager;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (_contextManager.IsLoaded && _contextManager.AssemblyPath != null)
                {
                    await EnsureWatcherSetup(_contextManager.AssemblyPath);
                }

                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in file watcher service");
                await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
            }
        }
    }

    private async Task EnsureWatcherSetup(string assemblyPath)
    {
        var directory = Path.GetDirectoryName(assemblyPath);
        if (directory == null || _watcher?.Path == directory) return;

        _watcher?.Dispose();
        _watcher = new FileSystemWatcher(directory, "*.dll")
        {
            NotifyFilter = NotifyFilters.LastWrite | NotifyFilters.Size,
            EnableRaisingEvents = true
        };

        _watcher.Changed += OnFileChanged;
        _watcher.Created += OnFileChanged;
        _watcher.Renamed += OnFileRenamed;

        _logger.LogInformation("File watcher setup for directory: {Directory}", directory);

        // Initialize hash for current assembly
        await UpdateFileHash(assemblyPath);
    }

    private async void OnFileChanged(object sender, FileSystemEventArgs e)
    {
        if (Path.GetExtension(e.FullPath) != ".dll") return;

        _logger.LogDebug("File change detected: {FilePath}", e.FullPath);

        // Debounce multiple rapid changes
        await Task.Delay(500);

        await HandleFileChange(e.FullPath);
    }

    private async void OnFileRenamed(object sender, RenamedEventArgs e)
    {
        if (Path.GetExtension(e.FullPath) != ".dll") return;

        _logger.LogDebug("File renamed: {OldPath} -> {NewPath}", e.OldFullPath, e.FullPath);
        await HandleFileChange(e.FullPath);
    }

    private async Task HandleFileChange(string filePath)
    {
        if (!await _reloadSemaphore.WaitAsync(TimeSpan.FromSeconds(1))) return;

        try
        {
            var newHash = await ComputeFileHashAsync(filePath);
            if (_fileHashes.TryGetValue(filePath, out var oldHash) && newHash == oldHash)
            {
                _logger.LogDebug("File hash unchanged, ignoring: {FilePath}", filePath);
                return;
            }

            _fileHashes[filePath] = newHash;
            _logger.LogInformation("Assembly file changed: {FilePath} (Hash: {Hash})", filePath, newHash[..8]);

            await TriggerReload(filePath);
        }
        finally
        {
            _reloadSemaphore.Release();
        }
    }

    private async Task<string> ComputeFileHashAsync(string filePath)
    {
        try
        {
            using var stream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            var hash = await SHA256.HashDataAsync(stream);
            return Convert.ToHexString(hash);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to compute hash for {FilePath}", filePath);
            return DateTime.UtcNow.Ticks.ToString(); // Fallback to timestamp
        }
    }

    private async Task UpdateFileHash(string filePath)
    {
        var hash = await ComputeFileHashAsync(filePath);
        _fileHashes[filePath] = hash;
        _logger.LogDebug("Updated hash for {FilePath}: {Hash}", filePath, hash[..8]);
    }

    private async Task TriggerReload(string filePath)
    {
        if (_contextManager.AssemblyPath == filePath)
        {
            _logger.LogInformation("Reloading assembly: {FilePath}", filePath);

            try
            {
                // In container mode, we would signal for container restart
                // In executable mode, we reload the assembly context
                if (IsRunningInContainer())
                {
                    await TriggerContainerRestart();
                }
                else
                {
                    await ReloadAssemblyContext(filePath);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to reload assembly: {FilePath}", filePath);
            }
        }
    }

    private static bool IsRunningInContainer()
    {
        // Check if we're running in a container environment
        return Environment.GetEnvironmentVariable("DOTNET_RUNNING_IN_CONTAINER") == "true" ||
               File.Exists("/.dockerenv");
    }

    private async Task TriggerContainerRestart()
    {
        _logger.LogInformation("Container restart required - signaling shutdown");

        // In container mode, we exit with a specific code that the orchestrator can detect
        // The container orchestration layer will restart us with fresh state
        Environment.ExitCode = 42; // Custom exit code for "assembly changed"

        // Allow graceful shutdown
        await Task.Delay(TimeSpan.FromSeconds(1));
        Environment.Exit(42);
    }

    private async Task ReloadAssemblyContext(string filePath)
    {
        _logger.LogInformation("Reloading assembly context for: {FilePath}", filePath);

        // Clear existing context
        _contextManager.Dispose();

        // Wait a moment for file operations to complete
        await Task.Delay(TimeSpan.FromSeconds(1));

        // Reload the assembly
        var directory = Path.GetDirectoryName(filePath);
        _contextManager.LoadAssemblyDirect(filePath, directory != null ? [directory] : null);

        _logger.LogInformation("Assembly context reloaded successfully");
    }

    public override void Dispose()
    {
        _watcher?.Dispose();
        _reloadSemaphore.Dispose();
        base.Dispose();
    }
}