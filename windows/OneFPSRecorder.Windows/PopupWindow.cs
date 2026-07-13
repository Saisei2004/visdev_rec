using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;

namespace OneFPSRecorder.WindowsApp;

public sealed class PopupWindow : Window
{
    private readonly RecorderController _controller;
    private readonly Action _showSettings;
    private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromSeconds(1) };
    private Ellipse? _dot;
    private TextBlock? _stateText;
    private TextBlock? _elapsedText;
    private Button? _pauseButton;

    public PopupWindow(RecorderController controller, Action showSettings)
    {
        _controller = controller;
        _showSettings = showSettings;
        Title = "OneFPSRecorder Popup";
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        Topmost = true;
        ShowInTaskbar = false;
        ResizeMode = ResizeMode.NoResize;
        MouseLeftButtonDown += (_, eventArgs) => { if (eventArgs.ButtonState == MouseButtonState.Pressed) DragMove(); };
        LocationChanged += (_, _) => SavePosition();
        _controller.StateChanged += state => Dispatcher.Invoke(() => UpdateState(state));
        _timer.Tick += (_, _) => UpdateElapsed();
        _timer.Start();
        ApplyConfiguration();
    }

    public void ApplyConfiguration()
    {
        var settings = _controller.Config.Popup;
        _pauseButton = null;
        var minimal = settings.Mode == PopupMode.Minimal;
        Width = Math.Clamp(settings.Width, minimal ? 24 : 180, 900);
        Height = Math.Clamp(settings.Height, minimal ? 24 : 64, 320);
        if (settings.Left.HasValue) Left = settings.Left.Value;
        if (settings.Top.HasValue) Top = settings.Top.Value;

        var border = new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(230, 24, 28, 36)),
            BorderBrush = new SolidColorBrush(Color.FromRgb(80, 88, 102)),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(minimal ? 999 : 10),
            Padding = new Thickness(minimal ? 5 : 10),
        };
        var root = new StackPanel { Orientation = Orientation.Vertical };
        var statusRow = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = minimal ? HorizontalAlignment.Center : HorizontalAlignment.Left };
        _dot = new Ellipse { Width = minimal ? 12 : 10, Height = minimal ? 12 : 10, Margin = minimal ? new Thickness(0) : new Thickness(0, 3, 8, 0) };
        statusRow.Children.Add(_dot);
        if (!minimal)
        {
            _stateText = new TextBlock { Foreground = Brushes.White, FontWeight = FontWeights.SemiBold };
            statusRow.Children.Add(_stateText);
            if (settings.ShowRecordingName)
            {
                statusRow.Children.Add(new TextBlock { Text = $"  {_controller.Config.RecordingName}", Foreground = Brushes.LightGray });
            }
            if (settings.ShowElapsedTime)
            {
                _elapsedText = new TextBlock { Foreground = Brushes.LightGray, Margin = new Thickness(10, 0, 0, 0) };
                statusRow.Children.Add(_elapsedText);
            }
        }
        root.Children.Add(statusRow);

        if (!minimal)
        {
            var controls = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 9, 0, 0) };
            foreach (var item in PopupLayout.VisibleElements(settings))
            {
                Button? button;
                if (item == "pause")
                {
                    _pauseButton = MakeButton(_controller.State is RecorderState.Paused or RecorderState.PausedTargetMissing ? settings.ResumeText : settings.PauseText,
                        async () => { if (_controller.State is RecorderState.Paused or RecorderState.PausedTargetMissing) await _controller.ResumeAsync(); else await _controller.PauseAsync(); });
                    button = _pauseButton;
                }
                else
                {
                    button = item switch
                    {
                        "start" => MakeButton(settings.StartText, async () => await _controller.StartAsync()),
                        "stop" => MakeButton(settings.StopText, async () => await _controller.StopAsync()),
                        "settings" => MakeButton(settings.SettingsText, () => { _showSettings(); return Task.CompletedTask; }),
                        _ => null,
                    };
                }
                if (button is not null) controls.Children.Add(button);
            }
            root.Children.Add(controls);
        }
        border.Child = root;
        Content = border;
        UpdateState(_controller.State);
        UpdateElapsed();
        Visibility = settings.ShowPopup ? Visibility.Visible : Visibility.Hidden;
    }

    private static Button MakeButton(string text, Func<Task> action)
    {
        var button = new Button { Content = text, Margin = new Thickness(0, 0, 6, 0), Padding = new Thickness(9, 3, 9, 3), MinWidth = 44 };
        button.Click += async (_, _) => await action();
        return button;
    }

    private void UpdateState(RecorderState state)
    {
        if (_dot is not null)
        {
            _dot.Fill = state switch
            {
                RecorderState.Recording => Brushes.Red,
                RecorderState.Paused or RecorderState.PausedTargetMissing => Brushes.Goldenrod,
                RecorderState.Failed => Brushes.DarkRed,
                RecorderState.Saving or RecorderState.Recovering or RecorderState.Starting => Brushes.DodgerBlue,
                _ => Brushes.Gray,
            };
        }
        if (_stateText is not null) _stateText.Text = state switch
        {
            RecorderState.Recording => "録画中",
            RecorderState.Paused => "一時停止",
            RecorderState.PausedTargetMissing => "画面待ち",
            RecorderState.Saving => "保存中",
            RecorderState.Recovering => "復旧中",
            RecorderState.Failed => "保存失敗",
            RecorderState.Starting => "開始中",
            _ => "停止中",
        };
        if (_pauseButton is not null)
        {
            _pauseButton.Content = state is RecorderState.Paused or RecorderState.PausedTargetMissing
                ? _controller.Config.Popup.ResumeText
                : _controller.Config.Popup.PauseText;
        }
    }

    private void UpdateElapsed()
    {
        if (_elapsedText is null) return;
        var started = _controller.RecordingStartedAt;
        _elapsedText.Text = started.HasValue ? (DateTimeOffset.Now - started.Value).ToString(@"hh\:mm\:ss") : "00:00:00";
    }

    private void SavePosition()
    {
        if (!IsLoaded || double.IsNaN(Left) || double.IsNaN(Top)) return;
        _controller.Config.Popup.Left = Left;
        _controller.Config.Popup.Top = Top;
        _controller.UpdateConfig(_controller.Config);
    }
}
