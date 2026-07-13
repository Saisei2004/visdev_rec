using System.Collections.ObjectModel;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;

namespace OneFPSRecorder.WindowsApp;

public sealed class ReportDayViewModel
{
    public bool Selected { get; set; } = true;
    public string Date { get; set; } = "";
    public string Reporter { get; set; } = "";
    public string WorkPlan { get; set; } = "";
    public string Done { get; set; } = "";
    public string Blockers { get; set; } = "なし";
    public string Tomorrow { get; set; } = "";
    public string Status { get; set; } = "順調";
    public string Message { get; set; } = "";
    public string VideoLink { get; set; } = "";
}

public sealed class ReportBatchWindow : Window
{
    private readonly PythonReportBridge _bridge = new();
    private readonly ObservableCollection<ReportDayViewModel> _days = [];
    private readonly TextBox _month = new() { Text = DateTime.Now.ToString("yyyy-MM"), Width = 90 };
    private readonly DataGrid _grid = new() { AutoGenerateColumns = false, CanUserAddRows = false, CanUserDeleteRows = false, Margin = new Thickness(0, 8, 0, 8) };
    private readonly CheckBox _video = new() { Content = "動画をDriveへ", Margin = new Thickness(0, 0, 14, 0) };
    private readonly CheckBox _drive = new() { Content = "Drive月報を更新", Margin = new Thickness(0, 0, 14, 0) };
    private readonly CheckBox _slack = new() { Content = "Slack #日報の本人スレッドへ", Margin = new Thickness(0, 0, 14, 0) };
    private readonly TextBox _result = new() { IsReadOnly = true, AcceptsReturn = true, TextWrapping = TextWrapping.Wrap, Height = 150, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };

    public ReportBatchWindow()
    {
        Title = "月次一括日報 - OneFPSRecorder";
        Width = 1280;
        Height = 760;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        BuildUi();
        Loaded += async (_, _) => await LoadCandidatesAsync();
    }

    private void BuildUi()
    {
        var root = new Grid { Margin = new Thickness(12) };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        var top = new StackPanel { Orientation = Orientation.Horizontal };
        top.Children.Add(new TextBlock { Text = "対象月", VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 8, 0) });
        top.Children.Add(_month);
        var load = new Button { Content = "録画日を読込", Margin = new Thickness(8, 0, 0, 0), Padding = new Thickness(10, 4, 10, 4) };
        load.Click += async (_, _) => await LoadCandidatesAsync();
        top.Children.Add(load);
        Grid.SetRow(top, 0);
        root.Children.Add(top);

        AddColumn("対象", nameof(ReportDayViewModel.Selected), 48, checkbox: true);
        AddColumn("日付", nameof(ReportDayViewModel.Date), 90);
        AddColumn("担当者", nameof(ReportDayViewModel.Reporter), 100);
        AddColumn("業務プラン", nameof(ReportDayViewModel.WorkPlan), 150);
        AddColumn("やった", nameof(ReportDayViewModel.Done), 220);
        AddColumn("詰まった/判断待ち", nameof(ReportDayViewModel.Blockers), 180);
        AddColumn("明日", nameof(ReportDayViewModel.Tomorrow), 180);
        AddColumn("状態", nameof(ReportDayViewModel.Status), 90);
        AddColumn("補足", nameof(ReportDayViewModel.Message), 160);
        AddColumn("動画リンク", nameof(ReportDayViewModel.VideoLink), 180);
        _grid.ItemsSource = _days;
        Grid.SetRow(_grid, 1);
        root.Children.Add(_grid);

        var bottom = new StackPanel { Orientation = Orientation.Vertical };
        var destinations = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 8) };
        destinations.Children.Add(_video);
        destinations.Children.Add(_drive);
        destinations.Children.Add(_slack);
        var dryRun = new Button { Content = "dry-run", Padding = new Thickness(12, 4, 12, 4) };
        dryRun.Click += async (_, _) => await SubmitAsync(execute: false);
        var execute = new Button { Content = "許可を確認して実行", Padding = new Thickness(12, 4, 12, 4), Margin = new Thickness(8, 0, 0, 0) };
        execute.Click += async (_, _) => await SubmitAsync(execute: true);
        destinations.Children.Add(dryRun);
        destinations.Children.Add(execute);
        bottom.Children.Add(destinations);
        bottom.Children.Add(new TextBlock { Text = "参照できない情報源は結果内で not_checked のまま表示されます。", Margin = new Thickness(0, 0, 0, 6) });
        bottom.Children.Add(_result);
        Grid.SetRow(bottom, 2);
        root.Children.Add(bottom);
        Content = root;
    }

    private void AddColumn(string header, string property, double width, bool checkbox = false)
    {
        DataGridColumn column = checkbox
            ? new DataGridCheckBoxColumn { Header = header, Binding = new Binding(property) { UpdateSourceTrigger = UpdateSourceTrigger.PropertyChanged }, Width = width }
            : new DataGridTextColumn { Header = header, Binding = new Binding(property) { UpdateSourceTrigger = UpdateSourceTrigger.PropertyChanged }, Width = width };
        _grid.Columns.Add(column);
    }

    private async Task LoadCandidatesAsync()
    {
        try
        {
            _result.Text = "読込中...";
            using var document = await _bridge.CandidatesAsync(_month.Text.Trim());
            _days.Clear();
            foreach (var candidate in document.RootElement.GetProperty("unsubmitted").EnumerateArray())
            {
                var draft = candidate.GetProperty("defaultDraft");
                _days.Add(new ReportDayViewModel
                {
                    Date = candidate.GetProperty("date").GetString() ?? "",
                    Reporter = Get(draft, "reporter"),
                    WorkPlan = Get(draft, "workPlan"),
                    Done = Get(draft, "done"),
                    Blockers = Get(draft, "blockers"),
                    Tomorrow = Get(draft, "tomorrow"),
                    Status = Get(draft, "status"),
                    Message = Get(draft, "message"),
                    VideoLink = Get(draft, "videoLink"),
                });
            }
            _result.Text = JsonSerializer.Serialize(document.RootElement.GetProperty("configuration"), new JsonSerializerOptions { WriteIndented = true });
        }
        catch (Exception error)
        {
            _result.Text = error.Message;
        }
    }

    private async Task SubmitAsync(bool execute)
    {
        _grid.CommitEdit(DataGridEditingUnit.Cell, true);
        _grid.CommitEdit(DataGridEditingUnit.Row, true);
        var selected = _days.Where(day => day.Selected).ToArray();
        if (selected.Length == 0)
        {
            MessageBox.Show(this, "対象日を選択してください。", Title);
            return;
        }

        var video = _video.IsChecked == true;
        var drive = _drive.IsChecked == true;
        var slack = _slack.IsChecked == true;
        var permissions = new List<string>();
        var dates = string.Join(", ", selected.Select(day => day.Date));
        if (execute && video)
        {
            video = MessageBox.Show(this, $"今日の動画を投稿して良いですか。\n対象日: {dates}", "動画投稿の許可", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes;
            if (video) permissions.Add("video");
        }
        if (execute && drive)
        {
            drive = MessageBox.Show(this, $"Driveの報告書を自動で書いて良いですか。\n対象日: {dates}", "Drive更新の許可", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes;
            if (drive) permissions.Add("drive");
        }
        if (execute && slack)
        {
            slack = MessageBox.Show(this, $"Slackの日報を自動で書いて良いですか。\n対象日: {dates}", "Slack投稿の許可", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes;
            if (slack) permissions.Add("slack");
        }

        var request = new
        {
            reports = selected.Select(day => new
            {
                date = day.Date,
                reporter = day.Reporter,
                workPlan = day.WorkPlan,
                done = day.Done,
                blockers = day.Blockers,
                tomorrow = day.Tomorrow,
                status = day.Status,
                message = day.Message,
                videoLink = day.VideoLink,
            }).ToArray(),
            destinations = new { uploadVideoToDrive = video, updateDriveReport = drive, postToSlack = slack },
        };
        try
        {
            _result.Text = execute ? "実行中..." : "dry-run中...";
            _result.Text = await _bridge.SubmitAsync(request, execute, permissions);
            if (execute) await LoadCandidatesAsync();
        }
        catch (Exception error)
        {
            _result.Text = error.Message;
        }
    }

    private static string Get(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) ? value.GetString() ?? "" : "";
}
