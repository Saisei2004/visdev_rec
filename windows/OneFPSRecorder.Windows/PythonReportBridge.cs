using System.Diagnostics;
using System.Text;
using System.Text.Json;

namespace OneFPSRecorder.WindowsApp;

public sealed class PythonReportBridge
{
    private readonly string _script;

    public PythonReportBridge(string? script = null)
    {
        _script = script ?? Path.Combine(AppContext.BaseDirectory, "reporting", "reportctl.py");
    }

    public async Task<JsonDocument> CandidatesAsync(string month) =>
        JsonDocument.Parse(await RunAsync(["--report-candidates", month]));

    public async Task<string> SubmitAsync(object request, bool execute, IReadOnlyCollection<string> permissions)
    {
        var directory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OneFPSRecorder", "requests");
        Directory.CreateDirectory(directory);
        var requestPath = Path.Combine(directory, $"request-{Guid.NewGuid():N}.json");
        await File.WriteAllTextAsync(requestPath, JsonSerializer.Serialize(request, new JsonSerializerOptions { WriteIndented = true }), Encoding.UTF8);
        try
        {
            var arguments = new List<string> { "--submit-report-json", requestPath };
            if (execute)
            {
                arguments.Add("--execute");
                foreach (var permission in permissions)
                {
                    arguments.Add("--permission");
                    arguments.Add(permission);
                }
            }
            else
            {
                arguments.Add("--dry-run");
            }
            return await RunAsync(arguments);
        }
        finally
        {
            File.Delete(requestPath);
        }
    }

    private async Task<string> RunAsync(IReadOnlyList<string> arguments)
    {
        if (!File.Exists(_script)) throw new FileNotFoundException("reportctl.py が見つかりません", _script);
        var info = new ProcessStartInfo("py")
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
            WorkingDirectory = Path.GetDirectoryName(_script)!,
        };
        info.ArgumentList.Add("-3");
        info.ArgumentList.Add(_script);
        foreach (var argument in arguments) info.ArgumentList.Add(argument);
        using var process = Process.Start(info) ?? throw new InvalidOperationException("Pythonを開始できませんでした");
        var outputTask = process.StandardOutput.ReadToEndAsync();
        var errorTask = process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        var output = await outputTask;
        var error = await errorTask;
        if (process.ExitCode != 0) throw new InvalidOperationException(error.Trim());
        return output;
    }
}
