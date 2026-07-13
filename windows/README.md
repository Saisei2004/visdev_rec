# OneFPSRecorder / Visitas Task Hub for Windows

macOS版を変更せず、Windows用コードを独立配置した互換実装です。

## 構成

- `OneFPSRecorder.Windows/`: .NET 8 WPF、通知領域、前面ポップアップ、設定、月次一括UI
- Desktop Duplication API: ffmpegの `ddagrab` フィルターを1 FPSで使用
- 画面固定: monitor device interface pathとEDID由来の安定IDを保存。対象消失時は停止し、他画面へフォールバックしない
- `OneFPSRecorder.Windows/reporting/`: macOS互換のPython日報・提出状態コア
- `../tools/visitas-task-hub-windows/`: Box追記イベントを正典とするTask Hub互換層

## インストール

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\Install-OneFPSRecorder.Windows.ps1
```

標準配置先は `%LOCALAPPDATA%\OneFPSRecorder\app`、録画先は `%USERPROFILE%\Videos\1FPS録画` です。ログオン時に自動起動し、タスクバー右端の通知領域へ常駐します。手動起動はスタートメニューで `OneFPSRecorder Windows` を検索してください。通知領域アイコンのダブルクリックで設定、右クリックで録画操作や終了ができます。

## 安全な日報処理

候補取得と提出状態はmacOS版と同じ `業務報告データ-YYYY-MM.json` / `提出状態-YYYY-MM.json` を使います。宛先別の成功をOR更新し、成功済み宛先は再実行しません。既定はdry-runです。実行時も動画、Drive、Slackを個別に質問し、Slackは `#日報` の本人 `thread_ts` が無いと拒否します。

Slack WebhookはJSONへ書かず、Windows Credential Managerの `OneFPSRecorder/SlackWebhook` に保存します。

## 検証

```powershell
dotnet build .\windows\OneFPSRecorder.Windows\OneFPSRecorder.Windows.csproj -c Release
dotnet run --project .\windows\OneFPSRecorder.Windows.Tests\OneFPSRecorder.Windows.Tests.csproj -c Release
py -3 -m unittest discover -s .\windows\OneFPSRecorder.Windows\reporting\tests -v
```

実画面を5秒だけ録画するsmoke test:

```powershell
dotnet run --project .\windows\OneFPSRecorder.Windows.Tests\OneFPSRecorder.Windows.Tests.csproj -c Release -- --capture-smoke
```
