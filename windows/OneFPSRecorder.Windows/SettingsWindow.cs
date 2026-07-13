using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using Forms = System.Windows.Forms;

namespace OneFPSRecorder.WindowsApp;

public sealed class SettingsWindow : Window
{
    private readonly RecorderController _controller;
    private readonly MonitorService _monitorService;
    private readonly Action _saved;
    private readonly ComboBox _monitor = new() { MinWidth = 360 };
    private readonly TextBox _recordingName = new();
    private readonly TextBox _outputRoot = new();
    private readonly CheckBox _drawMouse = new() { Content = "マウスポインターを録画する" };
    private readonly TextBox _segmentMinutes = new();
    private readonly ComboBox _popupMode = new() { ItemsSource = Enum.GetValues<PopupMode>() };
    private readonly TextBox _popupWidth = new();
    private readonly TextBox _popupHeight = new();
    private readonly CheckBox _showPopup = new() { Content = "常に手前のポップアップを表示" };
    private readonly CheckBox _showName = new() { Content = "表示名" };
    private readonly CheckBox _showTime = new() { Content = "録画時間" };
    private readonly CheckBox _showStart = new() { Content = "開始" };
    private readonly CheckBox _showPause = new() { Content = "一時停止/再開" };
    private readonly CheckBox _showStop = new() { Content = "停止" };
    private readonly CheckBox _showSettings = new() { Content = "設定" };
    private readonly TextBox _controlOrder = new();
    private readonly TextBox _startText = new();
    private readonly TextBox _pauseText = new();
    private readonly TextBox _resumeText = new();
    private readonly TextBox _stopText = new();
    private readonly TextBox _settingsText = new();
    private readonly PasswordBox _slackWebhook = new();

    public SettingsWindow(RecorderController controller, MonitorService monitorService, Action saved)
    {
        _controller = controller;
        _monitorService = monitorService;
        _saved = saved;
        Title = "OneFPSRecorder Windows 設定";
        Width = 700;
        Height = 800;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        BuildUi();
        LoadValues();
    }

    private void BuildUi()
    {
        var panel = new StackPanel { Margin = new Thickness(18) };
        panel.Children.Add(Heading("録画"));
        AddField(panel, "固定するディスプレイ", _monitor);
        AddField(panel, "保存名", _recordingName);

        var outputRow = new DockPanel();
        var browse = new Button { Content = "参照...", Margin = new Thickness(8, 0, 0, 0), Padding = new Thickness(8, 2, 8, 2) };
        browse.Click += (_, _) => BrowseOutput();
        DockPanel.SetDock(browse, Dock.Right);
        outputRow.Children.Add(browse);
        outputRow.Children.Add(_outputRoot);
        AddField(panel, "保存フォルダ", outputRow);
        panel.Children.Add(_drawMouse);
        AddField(panel, "自動保存間隔（分）", _segmentMinutes);

        panel.Children.Add(Heading("ポップアップ"));
        panel.Children.Add(_showPopup);
        AddField(panel, "構成", _popupMode);
        var size = new StackPanel { Orientation = Orientation.Horizontal };
        _popupWidth.Width = 80;
        _popupHeight.Width = 80;
        size.Children.Add(_popupWidth);
        size.Children.Add(new TextBlock { Text = " × ", VerticalAlignment = VerticalAlignment.Center });
        size.Children.Add(_popupHeight);
        AddField(panel, "幅 × 高さ", size);
        var visible = new WrapPanel();
        foreach (var check in new[] { _showName, _showTime, _showStart, _showPause, _showStop, _showSettings })
        {
            check.Margin = new Thickness(0, 0, 14, 6);
            visible.Children.Add(check);
        }
        AddField(panel, "表示項目", visible);
        AddField(panel, "ボタン順（start,pause,stop,settings）", _controlOrder);
        var labels = new UniformGrid { Columns = 5 };
        foreach (var box in new[] { _startText, _pauseText, _resumeText, _stopText, _settingsText })
        {
            box.Margin = new Thickness(0, 0, 6, 0);
            labels.Children.Add(box);
        }
        AddField(panel, "表記（開始/一時停止/再開/停止/設定）", labels);

        panel.Children.Add(Heading("日報・秘密情報"));
        AddField(panel, "Slack Webhook（入力時だけCredential Managerへ保存）", _slackWebhook);

        var actions = new WrapPanel { Margin = new Thickness(0, 18, 0, 0) };
        actions.Children.Add(ActionButton("保存", (_, _) => SaveValues()));
        actions.Children.Add(ActionButton("録画開始", async (_, _) => await _controller.StartAsync()));
        actions.Children.Add(ActionButton("一時停止/再開", async (_, _) => { if (_controller.State is RecorderState.Paused or RecorderState.PausedTargetMissing) await _controller.ResumeAsync(); else await _controller.PauseAsync(); }));
        actions.Children.Add(ActionButton("停止", async (_, _) => await _controller.StopAsync()));
        actions.Children.Add(ActionButton("月次一括日報...", (_, _) => new ReportBatchWindow().Show()));
        actions.Children.Add(ActionButton("保存先を開く", (_, _) => OpenOutput()));
        panel.Children.Add(actions);

        Content = new ScrollViewer { Content = panel, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
    }

    private void LoadValues()
    {
        var config = _controller.Config;
        var monitors = _monitorService.GetMonitors();
        _monitor.ItemsSource = monitors;
        _monitor.SelectedItem = MonitorIdentityResolver.Resolve(monitors, config.SelectedMonitorStableId)
            ?? monitors.FirstOrDefault(item => item.IsPrimary)
            ?? monitors.FirstOrDefault();
        _recordingName.Text = config.RecordingName;
        _outputRoot.Text = config.OutputRoot;
        _drawMouse.IsChecked = config.DrawMouse;
        _segmentMinutes.Text = config.SegmentMinutes.ToString();
        _popupMode.SelectedItem = config.Popup.Mode;
        _popupWidth.Text = config.Popup.Width.ToString("0");
        _popupHeight.Text = config.Popup.Height.ToString("0");
        _showPopup.IsChecked = config.Popup.ShowPopup;
        _showName.IsChecked = config.Popup.ShowRecordingName;
        _showTime.IsChecked = config.Popup.ShowElapsedTime;
        _showStart.IsChecked = config.Popup.ShowStartButton;
        _showPause.IsChecked = config.Popup.ShowPauseButton;
        _showStop.IsChecked = config.Popup.ShowStopButton;
        _showSettings.IsChecked = config.Popup.ShowSettingsButton;
        _controlOrder.Text = string.Join(",", config.Popup.ControlOrder);
        _startText.Text = config.Popup.StartText;
        _pauseText.Text = config.Popup.PauseText;
        _resumeText.Text = config.Popup.ResumeText;
        _stopText.Text = config.Popup.StopText;
        _settingsText.Text = config.Popup.SettingsText;
    }

    private void SaveValues()
    {
        if (_monitor.SelectedItem is not MonitorDescriptor selected)
        {
            MessageBox.Show(this, "録画するディスプレイを選択してください。", Title);
            return;
        }
        var config = _controller.Config;
        config.SelectedMonitorStableId = selected.StableId;
        config.SelectedMonitorDevicePath = selected.DevicePath;
        config.RecordingName = string.IsNullOrWhiteSpace(_recordingName.Text) ? "録画" : _recordingName.Text.Trim();
        config.OutputRoot = _outputRoot.Text.Trim();
        config.DrawMouse = _drawMouse.IsChecked == true;
        config.SegmentMinutes = int.TryParse(_segmentMinutes.Text, out var minutes) ? Math.Clamp(minutes, 1, 120) : 15;
        config.Popup.Mode = _popupMode.SelectedItem is PopupMode mode ? mode : PopupMode.Standard;
        config.Popup.Width = double.TryParse(_popupWidth.Text, out var width) ? width : 320;
        config.Popup.Height = double.TryParse(_popupHeight.Text, out var height) ? height : 96;
        config.Popup.ShowPopup = _showPopup.IsChecked == true;
        config.Popup.ShowRecordingName = _showName.IsChecked == true;
        config.Popup.ShowElapsedTime = _showTime.IsChecked == true;
        config.Popup.ShowStartButton = _showStart.IsChecked == true;
        config.Popup.ShowPauseButton = _showPause.IsChecked == true;
        config.Popup.ShowStopButton = _showStop.IsChecked == true;
        config.Popup.ShowSettingsButton = _showSettings.IsChecked == true;
        config.Popup.ControlOrder = _controlOrder.Text.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries).Where(item => item is "start" or "pause" or "stop" or "settings").Distinct().ToList();
        config.Popup.StartText = ValueOr(_startText.Text, "開始");
        config.Popup.PauseText = ValueOr(_pauseText.Text, "一時停止");
        config.Popup.ResumeText = ValueOr(_resumeText.Text, "再開");
        config.Popup.StopText = ValueOr(_stopText.Text, "停止");
        config.Popup.SettingsText = ValueOr(_settingsText.Text, "設定");
        Directory.CreateDirectory(config.OutputRoot);
        _controller.UpdateConfig(config);
        if (!string.IsNullOrWhiteSpace(_slackWebhook.Password))
        {
            if (!_slackWebhook.Password.StartsWith("https://hooks.slack.com/", StringComparison.OrdinalIgnoreCase))
            {
                MessageBox.Show(this, "Slack Webhookはhooks.slack.comのHTTPS URLを指定してください。", Title);
                return;
            }
            CredentialStore.Write("OneFPSRecorder/SlackWebhook", _slackWebhook.Password);
            _slackWebhook.Clear();
        }
        _saved();
        MessageBox.Show(this, "設定を保存しました。ディスプレイIDは再起動後も維持されます。", Title);
    }

    private void BrowseOutput()
    {
        using var dialog = new Forms.FolderBrowserDialog { InitialDirectory = _outputRoot.Text, UseDescriptionForTitle = true, Description = "録画保存フォルダ" };
        if (dialog.ShowDialog() == Forms.DialogResult.OK) _outputRoot.Text = dialog.SelectedPath;
    }

    private void OpenOutput()
    {
        Directory.CreateDirectory(_controller.Config.OutputRoot);
        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("explorer.exe", _controller.Config.OutputRoot) { UseShellExecute = true });
    }

    private static TextBlock Heading(string text) => new() { Text = text, FontSize = 17, FontWeight = FontWeights.Bold, Margin = new Thickness(0, 16, 0, 8) };

    private static void AddField(Panel panel, string label, UIElement control)
    {
        panel.Children.Add(new TextBlock { Text = label, Margin = new Thickness(0, 7, 0, 3) });
        panel.Children.Add(control);
    }

    private static Button ActionButton(string text, RoutedEventHandler handler)
    {
        var button = new Button { Content = text, Margin = new Thickness(0, 0, 8, 8), Padding = new Thickness(10, 5, 10, 5) };
        button.Click += handler;
        return button;
    }

    private static string ValueOr(string value, string fallback) => string.IsNullOrWhiteSpace(value) ? fallback : value.Trim();
}
