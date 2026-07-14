using System.Diagnostics;
using System.Text;
using System.Text.Json;

namespace OneFPSRecorder.WindowsApp;

public sealed class RecorderController : IDisposable
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };
    private readonly ConfigStore _configStore;
    private readonly MonitorService _monitorService;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly string _segmentsRoot;
    private readonly System.Threading.Timer _watchdog;
    private Process? _process;
    private SegmentMetadata? _segment;
    private MonitorDescriptor? _activeMonitor;
    private bool _expectedExit;
    private int _watchdogBusy;
    private DateTimeOffset? _recordingStartedAt;
    private bool _disposed;

    public RecorderController(ConfigStore configStore, MonitorService monitorService, string? segmentsRoot = null)
    {
        _configStore = configStore;
        _monitorService = monitorService;
        Config = configStore.Load();
        _segmentsRoot = segmentsRoot ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "OneFPSRecorder", "segments");
        Directory.CreateDirectory(_segmentsRoot);
        _watchdog = new System.Threading.Timer(_ => _ = WatchdogAsync(), null, TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(2));
    }

    public AppConfig Config { get; private set; }
    public RecorderState State { get; private set; } = RecorderState.Idle;
    public DateTimeOffset? RecordingStartedAt => _recordingStartedAt;
    public event Action<RecorderState>? StateChanged;
    public event Action<string>? NotificationRequested;

    public void UpdateConfig(AppConfig config)
    {
        Config = config;
        _configStore.Save(config);
    }

    public async Task RecoverAsync()
    {
        await _gate.WaitAsync();
        try
        {
            SetState(RecorderState.Recovering);
            var recovered = 0;
            var failed = 0;
            foreach (var metadataPath in Directory.EnumerateFiles(_segmentsRoot, "segment.json", SearchOption.AllDirectories))
            {
                try
                {
                    var metadata = JsonSerializer.Deserialize<SegmentMetadata>(await File.ReadAllTextAsync(metadataPath), JsonOptions);
                    if (metadata is null) continue;
                    var pending = Path.Combine(Path.GetDirectoryName(metadataPath)!, "pending.mp4");
                    if (!File.Exists(pending) || new FileInfo(pending).Length < 512) continue;
                    await FinalizeSegmentAsync(metadata, pending);
                    recovered++;
                }
                catch (Exception error)
                {
                    Log($"Recovery failed for {metadataPath}: {error}");
                    failed++;
                }
            }
            if (recovered > 0 || failed > 0)
            {
                Notify($"録画復旧: 成功 {recovered} / 失敗 {failed}");
            }
            SetState(RecorderState.Idle);
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task StartAsync()
    {
        await _gate.WaitAsync();
        try
        {
            if (State is RecorderState.Recording or RecorderState.Starting or RecorderState.Saving) return;
            if (_process is not null && _segment is not null)
            {
                await StopProcessAndFinalizeLockedAsync();
            }
            await StartLockedAsync();
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task PauseAsync(bool targetMissing = false)
    {
        await _gate.WaitAsync();
        try
        {
            if (State != RecorderState.Recording) return;
            await StopProcessAndFinalizeLockedAsync();
            SetState(targetMissing ? RecorderState.PausedTargetMissing : RecorderState.Paused);
            if (targetMissing) Notify("固定したディスプレイが見つからないため録画を停止しました。別画面には切り替えていません。");
        }
        finally
        {
            _gate.Release();
        }
    }

    public Task ResumeAsync() => StartAsync();

    public async Task StopAsync()
    {
        await _gate.WaitAsync();
        try
        {
            if (_process is not null && _segment is not null)
            {
                await StopProcessAndFinalizeLockedAsync();
            }
            SetState(RecorderState.Idle);
            _recordingStartedAt = null;
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task StartLockedAsync()
    {
        SetState(RecorderState.Starting);
        var monitors = _monitorService.GetMonitors();
        if (string.IsNullOrWhiteSpace(Config.SelectedMonitorStableId))
        {
            var initial = monitors.FirstOrDefault(item => item.IsPrimary) ?? monitors.FirstOrDefault();
            if (initial is null)
            {
                SetState(RecorderState.PausedTargetMissing);
                Notify("録画可能なディスプレイが見つかりません。");
                return;
            }
            Config.SelectedMonitorStableId = initial.StableId;
            Config.SelectedMonitorDevicePath = initial.DevicePath;
            _configStore.Save(Config);
        }

        var monitor = MonitorIdentityResolver.Resolve(monitors, Config.SelectedMonitorStableId);
        if (monitor is null)
        {
            SetState(RecorderState.PausedTargetMissing);
            Notify("固定したディスプレイが見つかりません。設定から同じ画面を再接続してください。");
            return;
        }

        var now = DateTimeOffset.Now;
        var segmentDirectory = Path.Combine(_segmentsRoot, $"segment-{now:yyyyMMdd-HHmmss}-{Guid.NewGuid():N}");
        Directory.CreateDirectory(segmentDirectory);
        var pending = Path.Combine(segmentDirectory, "pending.mp4");
        _segment = new SegmentMetadata
        {
            SegmentId = Path.GetFileName(segmentDirectory),
            StartedAt = now,
            MonitorStableId = monitor.StableId,
            MonitorDevicePath = monitor.DevicePath,
            DdaOutputIndex = monitor.DdaOutputIndex,
            OutputRoot = Config.OutputRoot,
            RecordingName = SanitizeName(Config.RecordingName),
        };
        await File.WriteAllTextAsync(Path.Combine(segmentDirectory, "segment.json"), JsonSerializer.Serialize(_segment, JsonOptions));

        var startInfo = BuildCaptureStartInfo(FfmpegLocator.Find(), monitor.DdaOutputIndex, pending, Config.DrawMouse);
        var stderrPath = Path.Combine(segmentDirectory, "ffmpeg.log");
        _expectedExit = false;
        _process = new Process { StartInfo = startInfo, EnableRaisingEvents = true };
        _process.ErrorDataReceived += (_, eventArgs) =>
        {
            if (!string.IsNullOrWhiteSpace(eventArgs.Data)) File.AppendAllText(stderrPath, eventArgs.Data + Environment.NewLine);
        };
        _process.Exited += (_, _) => _ = HandleProcessExitAsync();
        if (!_process.Start()) throw new InvalidOperationException("ffmpegを開始できませんでした");
        _process.BeginErrorReadLine();
        await Task.Delay(700);
        if (_process.HasExited)
        {
            SetState(RecorderState.Failed);
            Notify($"録画開始に失敗しました。ログ: {stderrPath}");
            return;
        }

        _activeMonitor = monitor;
        _recordingStartedAt ??= now;
        SetState(RecorderState.Recording);
        Log($"Recording started monitor={monitor.StableId} output={monitor.DdaOutputIndex}");
    }

    private static ProcessStartInfo BuildCaptureStartInfo(string ffmpeg, int outputIndex, string pending, bool drawMouse)
    {
        var filter = $"ddagrab=output_idx={outputIndex}:framerate=1:draw_mouse={(drawMouse ? 1 : 0)}:dup_frames=1,hwdownload,format=bgra,scale=960:600:force_original_aspect_ratio=decrease,pad=960:600:(ow-iw)/2:(oh-ih)/2[out]";
        var info = new ProcessStartInfo(ffmpeg)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardInput = true,
            RedirectStandardError = true,
            RedirectStandardOutput = false,
        };
        foreach (var argument in new[]
        {
            "-hide_banner", "-loglevel", "warning", "-y",
            "-filter_complex", filter, "-map", "[out]",
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "28",
            "-r", "1", "-pix_fmt", "yuv420p", "-fps_mode", "cfr",
            "-movflags", "+frag_keyframe+empty_moov+default_base_moof", pending,
        }) info.ArgumentList.Add(argument);
        return info;
    }

    private async Task StopProcessAndFinalizeLockedAsync()
    {
        var process = _process;
        var metadata = _segment;
        if (process is null || metadata is null) return;
        SetState(RecorderState.Saving);
        _expectedExit = true;
        try
        {
            if (!process.HasExited)
            {
                await process.StandardInput.WriteLineAsync("q");
                await process.StandardInput.FlushAsync();
                var completed = await Task.WhenAny(process.WaitForExitAsync(), Task.Delay(TimeSpan.FromSeconds(12)));
                if (!process.HasExited && completed is not Task<int>) process.Kill(entireProcessTree: true);
                await process.WaitForExitAsync();
            }
        }
        finally
        {
            var segmentDirectory = Path.Combine(_segmentsRoot, metadata.SegmentId);
            var pending = Path.Combine(segmentDirectory, "pending.mp4");
            process.Dispose();
            _process = null;
            _segment = null;
            _activeMonitor = null;
            if (File.Exists(pending) && new FileInfo(pending).Length >= 512)
            {
                await FinalizeSegmentAsync(metadata, pending);
            }
            else
            {
                Notify("録画データを保存できませんでした。一時フォルダを保持します。");
            }
        }
    }

    private async Task FinalizeSegmentAsync(SegmentMetadata metadata, string pending)
    {
        var localStarted = metadata.StartedAt.LocalDateTime;
        var dayDirectory = Path.Combine(metadata.OutputRoot, localStarted.ToString("yyyy-MM"), localStarted.ToString("MMdd"));
        Directory.CreateDirectory(dayDirectory);
        var target = Path.Combine(dayDirectory, $"{localStarted:MMdd}_{SanitizeName(metadata.RecordingName)}.mp4");
        if (!File.Exists(target))
        {
            File.Move(pending, target);
        }
        else
        {
            var list = Path.Combine(dayDirectory, $".concat-{Guid.NewGuid():N}.txt");
            var combined = Path.Combine(dayDirectory, $".combined-{Guid.NewGuid():N}.mp4");
            var backup = target + ".bak";
            await File.WriteAllLinesAsync(list, [$"file '{ConcatPath(target)}'", $"file '{ConcatPath(pending)}'"]);
            try
            {
                var info = new ProcessStartInfo(FfmpegLocator.Find()) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardError = true };
                foreach (var argument in new[] { "-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", list, "-c", "copy", "-movflags", "+faststart", combined }) info.ArgumentList.Add(argument);
                using var concat = Process.Start(info) ?? throw new InvalidOperationException("ffmpeg concatを開始できませんでした");
                var error = await concat.StandardError.ReadToEndAsync();
                await concat.WaitForExitAsync();
                if (concat.ExitCode != 0) throw new InvalidOperationException($"ffmpeg concat failed: {error}");
                if (File.Exists(backup)) File.Delete(backup);
                File.Replace(combined, target, backup, ignoreMetadataErrors: true);
                File.Delete(backup);
                File.Delete(pending);
            }
            finally
            {
                if (File.Exists(list)) File.Delete(list);
                if (File.Exists(combined)) File.Delete(combined);
            }
        }

        var ended = DateTimeOffset.Now;
        var intervalLog = Path.Combine(dayDirectory, $"録画区間ログ-{localStarted:yyyy-MM-dd}.txt");
        await File.AppendAllTextAsync(intervalLog, $"{metadata.StartedAt:O}\t{ended:O}\t{metadata.SegmentId}\t{metadata.MonitorStableId}{Environment.NewLine}", Encoding.UTF8);
        var directory = Path.GetDirectoryName(pending)!;
        try { Directory.Delete(directory, recursive: true); } catch (IOException) { }
        Log($"Recording saved target={target}");
    }

    private async Task WatchdogAsync()
    {
        if (Interlocked.Exchange(ref _watchdogBusy, 1) == 1) return;
        try
        {
            if (State != RecorderState.Recording || _activeMonitor is null || _segment is null) return;
            var current = MonitorIdentityResolver.Resolve(_monitorService.GetMonitors(), _activeMonitor.StableId);
            if (current is null || current.DdaOutputIndex != _activeMonitor.DdaOutputIndex)
            {
                await PauseAsync(targetMissing: true);
                return;
            }
            var elapsed = DateTimeOffset.Now - _segment.StartedAt;
            if (DateTimeOffset.Now.LocalDateTime.Date != _segment.StartedAt.LocalDateTime.Date || elapsed >= TimeSpan.FromMinutes(Math.Clamp(Config.SegmentMinutes, 1, 120)))
            {
                await RotateAsync();
            }
        }
        catch (Exception error)
        {
            Log($"Watchdog failed: {error}");
        }
        finally
        {
            Interlocked.Exchange(ref _watchdogBusy, 0);
        }
    }

    private async Task RotateAsync()
    {
        await _gate.WaitAsync();
        try
        {
            if (State != RecorderState.Recording) return;
            await StopProcessAndFinalizeLockedAsync();
            await StartLockedAsync();
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task HandleProcessExitAsync()
    {
        await Task.Delay(100);
        if (_expectedExit || State != RecorderState.Recording) return;
        SetState(RecorderState.Failed);
        Notify("録画プロセスが停止しました。一時データを保持し、次回起動時に復旧します。");
    }

    private static string ConcatPath(string path) => Path.GetFullPath(path).Replace('\\', '/').Replace("'", "'\\''");

    private static string SanitizeName(string value)
    {
        var invalid = Path.GetInvalidFileNameChars();
        var cleaned = new string((string.IsNullOrWhiteSpace(value) ? "録画" : value.Trim()).Select(character => invalid.Contains(character) ? '-' : character).ToArray());
        return cleaned.Length > 48 ? cleaned[..48] : cleaned;
    }

    private void SetState(RecorderState state)
    {
        State = state;
        StateChanged?.Invoke(state);
    }

    private void Notify(string message) => NotificationRequested?.Invoke(message);

    private static void Log(string message)
    {
        var directory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OneFPSRecorder");
        Directory.CreateDirectory(directory);
        File.AppendAllText(Path.Combine(directory, "OneFPSRecorder.log"), $"{DateTimeOffset.Now:O}\t{message}{Environment.NewLine}");
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _watchdog.Dispose();
        _process?.Dispose();
        _gate.Dispose();
    }

    private sealed class SegmentMetadata
    {
        public string SegmentId { get; set; } = "";
        public DateTimeOffset StartedAt { get; set; }
        public string MonitorStableId { get; set; } = "";
        public string MonitorDevicePath { get; set; } = "";
        public int DdaOutputIndex { get; set; }
        public string OutputRoot { get; set; } = "";
        public string RecordingName { get; set; } = "録画";
    }
}
