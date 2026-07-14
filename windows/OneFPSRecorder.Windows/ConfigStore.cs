using System.Text.Json;

namespace OneFPSRecorder.WindowsApp;

public sealed class ConfigStore
{
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };

    public ConfigStore(string? path = null)
    {
        Path = path ?? System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "OneFPSRecorder",
            "settings.json");
    }

    public string Path { get; }

    public AppConfig Load()
    {
        try
        {
            var value = JsonSerializer.Deserialize<AppConfig>(File.ReadAllText(Path), Options);
            return value ?? new AppConfig();
        }
        catch (Exception error) when (error is IOException or JsonException or UnauthorizedAccessException)
        {
            return new AppConfig();
        }
    }

    public void Save(AppConfig value)
    {
        var directory = System.IO.Path.GetDirectoryName(Path)!;
        Directory.CreateDirectory(directory);
        var temporary = System.IO.Path.Combine(directory, $".{System.IO.Path.GetFileName(Path)}.{Environment.ProcessId}.tmp");
        File.WriteAllText(temporary, JsonSerializer.Serialize(value, Options));
        File.Move(temporary, Path, true);
    }
}
