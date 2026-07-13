using System.Drawing;
using System.Windows;
using Forms = System.Windows.Forms;

namespace OneFPSRecorder.WindowsApp;

public sealed class AppHost : IDisposable
{
    private readonly ConfigStore _configStore = new();
    private readonly MonitorService _monitorService = new();
    private readonly RecorderController _controller;
    private readonly Forms.NotifyIcon _tray;
    private readonly Forms.ToolStripMenuItem _stateItem = new("状態: 停止中") { Enabled = false };
    private PopupWindow? _popup;
    private SettingsWindow? _settings;
    private bool _disposed;

    public AppHost()
    {
        _controller = new RecorderController(_configStore, _monitorService);
        _controller.NotificationRequested += message => Application.Current.Dispatcher.Invoke(() => Notify(message));
        _controller.StateChanged += state => Application.Current.Dispatcher.Invoke(() => _stateItem.Text = $"状態: {StateText(state)}");
        _tray = new Forms.NotifyIcon
        {
            Text = "OneFPSRecorder",
            Icon = SystemIcons.Application,
            Visible = true,
            ContextMenuStrip = BuildMenu(),
        };
        _tray.DoubleClick += (_, _) => ShowSettings();
    }

    public async Task InitializeAsync()
    {
        await _controller.RecoverAsync();
        _popup = new PopupWindow(_controller, ShowSettings);
        _popup.Show();
        if (string.IsNullOrWhiteSpace(_controller.Config.SelectedMonitorStableId)) ShowSettings();
    }

    private Forms.ContextMenuStrip BuildMenu()
    {
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add(_stateItem);
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("録画開始", null, async (_, _) => await _controller.StartAsync());
        menu.Items.Add("一時停止", null, async (_, _) => await _controller.PauseAsync());
        menu.Items.Add("録画再開", null, async (_, _) => await _controller.ResumeAsync());
        menu.Items.Add("停止", null, async (_, _) => await _controller.StopAsync());
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("ポップアップを表示", null, (_, _) => { _popup?.Show(); _popup?.Activate(); });
        menu.Items.Add("月次一括日報...", null, (_, _) => new ReportBatchWindow().Show());
        menu.Items.Add("設定...", null, (_, _) => ShowSettings());
        menu.Items.Add("保存フォルダを開く", null, (_, _) => OpenOutput());
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("終了", null, async (_, _) => await ExitAsync());
        return menu;
    }

    private void ShowSettings()
    {
        if (_settings is null || !_settings.IsLoaded)
        {
            _settings = new SettingsWindow(_controller, _monitorService, () => _popup?.ApplyConfiguration());
            _settings.Closed += (_, _) => _settings = null;
            _settings.Show();
        }
        else
        {
            _settings.Activate();
        }
    }

    private void OpenOutput()
    {
        Directory.CreateDirectory(_controller.Config.OutputRoot);
        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("explorer.exe", _controller.Config.OutputRoot) { UseShellExecute = true });
    }

    private void Notify(string message)
    {
        _tray.BalloonTipTitle = "OneFPSRecorder";
        _tray.BalloonTipText = message;
        _tray.ShowBalloonTip(5000);
    }

    private async Task ExitAsync()
    {
        await _controller.StopAsync();
        Dispose();
        Application.Current.Shutdown();
    }

    private static string StateText(RecorderState state) => state switch
    {
        RecorderState.Recording => "録画中",
        RecorderState.Paused => "一時停止",
        RecorderState.PausedTargetMissing => "固定画面待ち",
        RecorderState.Saving => "保存中",
        RecorderState.Recovering => "復旧中",
        RecorderState.Failed => "失敗",
        RecorderState.Starting => "開始中",
        _ => "停止中",
    };

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _tray.Visible = false;
        _tray.Dispose();
        _controller.Dispose();
        _popup?.Close();
        _settings?.Close();
    }
}
