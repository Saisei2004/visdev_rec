using System.Diagnostics;

namespace OneFPSRecorder.WindowsApp;

public static class FfmpegLocator
{
    public static string Find()
    {
        var candidates = new[]
        {
            Environment.GetEnvironmentVariable("ONEFPS_FFMPEG"),
            Path.Combine(AppContext.BaseDirectory, "tools", "ffmpeg.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Microsoft", "WinGet", "Links", "ffmpeg.exe"),
        };
        foreach (var candidate in candidates)
        {
            if (!string.IsNullOrWhiteSpace(candidate) && File.Exists(candidate)) return candidate;
        }

        var pathValue = Environment.GetEnvironmentVariable("PATH") ?? "";
        foreach (var directory in pathValue.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
        {
            var candidate = Path.Combine(directory.Trim('"'), "ffmpeg.exe");
            if (File.Exists(candidate)) return candidate;
        }
        throw new FileNotFoundException("ffmpeg.exe が見つかりません。Install-OneFPSRecorder.Windows.ps1 を再実行してください。");
    }
}
