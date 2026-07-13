using OneFPSRecorder.WindowsApp;

static void Assert(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}

static MonitorDescriptor Monitor(string id, int index = 0) =>
    new(id, $"Monitor {id}", $@"\\.\DISPLAY{index + 1}", $"device-{id}", $"edid-{id}", index, 0, 0, 1920, 1080, index == 0);

static void RunUnitTests()
{
    var monitors = new[] { Monitor("stable-a"), Monitor("stable-b", 1) };
    Assert(MonitorIdentityResolver.Resolve(monitors, "stable-b")?.DdaOutputIndex == 1, "stable monitor resolution failed");
    Assert(MonitorIdentityResolver.Resolve(monitors, "missing") is null, "missing monitor must not fall back to another display");

    var minimal = new PopupSettings { Mode = PopupMode.Minimal, ShowStartButton = true, ShowElapsedTime = true };
    Assert(PopupLayout.VisibleElements(minimal).SequenceEqual(["state-dot"]), "minimal popup must show only recording state");

    var directory = Path.Combine(Path.GetTempPath(), $"OneFPSRecorderConfigTest-{Guid.NewGuid():N}");
    Directory.CreateDirectory(directory);
    try
    {
        var store = new ConfigStore(Path.Combine(directory, "settings.json"));
        var config = new AppConfig { SelectedMonitorStableId = "stable-b", SelectedMonitorDevicePath = "device-b" };
        config.Popup.Mode = PopupMode.Custom;
        config.Popup.ControlOrder = ["stop", "start"];
        store.Save(config);
        var reloaded = store.Load();
        Assert(reloaded.SelectedMonitorStableId == "stable-b", "monitor ID did not survive reload");
        Assert(reloaded.Popup.ControlOrder.SequenceEqual(["stop", "start"]), "popup customization did not survive reload");
    }
    finally
    {
        Directory.Delete(directory, true);
    }

    var physical = new MonitorService().GetMonitors();
    Assert(physical.Count > 0, "no active monitor found");
    Assert(physical.All(item => !string.IsNullOrWhiteSpace(item.StableId) && !string.IsNullOrWhiteSpace(item.DevicePath)), "monitor stable identity is incomplete");
    Console.WriteLine($"UNIT TESTS PASSED ({physical.Count} monitor(s))");
    foreach (var item in physical)
    {
        Console.WriteLine($"MONITOR stable={item.StableId[..12]} output={item.DdaOutputIndex} size={item.Width}x{item.Height} primary={item.IsPrimary}");
    }
}

static async Task RunCaptureSmokeAsync()
{
    var directory = Path.Combine(Path.GetTempPath(), $"OneFPSRecorderSmoke-{Guid.NewGuid():N}");
    var output = Path.Combine(directory, "recordings");
    var segments = Path.Combine(directory, "segments");
    Directory.CreateDirectory(directory);
    var store = new ConfigStore(Path.Combine(directory, "settings.json"));
    var monitorService = new MonitorService();
    var monitor = monitorService.GetMonitors().FirstOrDefault(item => item.IsPrimary) ?? monitorService.GetMonitors().First();
    var config = new AppConfig
    {
        RecordingName = "smoke-test",
        OutputRoot = output,
        SelectedMonitorStableId = monitor.StableId,
        SelectedMonitorDevicePath = monitor.DevicePath,
        SegmentMinutes = 15,
    };
    store.Save(config);
    using var controller = new RecorderController(store, monitorService, segments);
    var notices = new List<string>();
    controller.NotificationRequested += notices.Add;
    await controller.RecoverAsync();
    await controller.StartAsync();
    Assert(controller.State == RecorderState.Recording, "capture did not enter Recording state: " + string.Join(" | ", notices));
    await Task.Delay(TimeSpan.FromSeconds(5));
    await controller.StopAsync();
    Assert(controller.State == RecorderState.Idle, "capture did not return to Idle");
    var video = Directory.EnumerateFiles(output, "*.mp4", SearchOption.AllDirectories).SingleOrDefault();
    Assert(video is not null && new FileInfo(video).Length > 512, "capture did not create a video");
    Console.WriteLine($"CAPTURE SMOKE PASSED: {video}");
}

try
{
    RunUnitTests();
    if (args.Contains("--capture-smoke")) await RunCaptureSmokeAsync();
    return 0;
}
catch (Exception error)
{
    Console.Error.WriteLine(error);
    return 1;
}
