namespace OneFPSRecorder.WindowsApp;

public enum RecorderState
{
    Idle,
    Starting,
    Recording,
    Paused,
    PausedTargetMissing,
    Saving,
    Recovering,
    Failed
}

public enum PopupMode
{
    Standard,
    Minimal,
    Custom
}

public sealed class PopupSettings
{
    public PopupMode Mode { get; set; } = PopupMode.Standard;
    public double Width { get; set; } = 320;
    public double Height { get; set; } = 96;
    public double? Left { get; set; }
    public double? Top { get; set; }
    public bool ShowPopup { get; set; } = true;
    public bool ShowRecordingName { get; set; } = true;
    public bool ShowElapsedTime { get; set; } = true;
    public bool ShowStartButton { get; set; } = true;
    public bool ShowPauseButton { get; set; } = true;
    public bool ShowStopButton { get; set; } = true;
    public bool ShowSettingsButton { get; set; } = true;
    public string StartText { get; set; } = "開始";
    public string PauseText { get; set; } = "一時停止";
    public string ResumeText { get; set; } = "再開";
    public string StopText { get; set; } = "停止";
    public string SettingsText { get; set; } = "設定";
    public List<string> ControlOrder { get; set; } = ["start", "pause", "stop", "settings"];
}

public sealed class AppConfig
{
    public int Version { get; set; } = 1;
    public string RecordingName { get; set; } = "録画";
    public string OutputRoot { get; set; } = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyVideos), "1FPS録画");
    public string SelectedMonitorStableId { get; set; } = "";
    public string SelectedMonitorDevicePath { get; set; } = "";
    public bool DrawMouse { get; set; } = true;
    public int SegmentMinutes { get; set; } = 15;
    public PopupSettings Popup { get; set; } = new();
}

public sealed record MonitorDescriptor(
    string StableId,
    string DisplayName,
    string DeviceName,
    string DevicePath,
    string EdidIdentity,
    int DdaOutputIndex,
    int Left,
    int Top,
    int Width,
    int Height,
    bool IsPrimary)
{
    public override string ToString() => $"{DisplayName} ({Width}x{Height}){(IsPrimary ? " [メイン]" : "")}";
}

public static class MonitorIdentityResolver
{
    public static MonitorDescriptor? Resolve(IEnumerable<MonitorDescriptor> monitors, string stableId) =>
        monitors.FirstOrDefault(item => string.Equals(item.StableId, stableId, StringComparison.OrdinalIgnoreCase));
}

public static class PopupLayout
{
    public static IReadOnlyList<string> VisibleElements(PopupSettings settings)
    {
        if (settings.Mode == PopupMode.Minimal)
        {
            return ["state-dot"];
        }

        var result = new List<string> { "state-dot" };
        if (settings.ShowRecordingName) result.Add("recording-name");
        if (settings.ShowElapsedTime) result.Add("elapsed-time");
        foreach (var name in settings.ControlOrder)
        {
            if (name == "start" && settings.ShowStartButton) result.Add("start");
            if (name == "pause" && settings.ShowPauseButton) result.Add("pause");
            if (name == "stop" && settings.ShowStopButton) result.Add("stop");
            if (name == "settings" && settings.ShowSettingsButton) result.Add("settings");
        }
        return result;
    }
}
