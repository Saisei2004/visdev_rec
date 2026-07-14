# Visitas Task Hub v2 for Windows

Boxの追記専用イベントを正典として、macOS版と同じPythonコアをWindowsへ配置する互換レイヤーです。`tasks.json` はローカル表示用キャッシュであり、イベントは作成専用モードで新規ファイルとしてだけ書きます。

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-Visitas-Task-Hub.ps1
```

標準配置先は `%USERPROFILE%\visitas-tasks` です。インストーラはBoxルートを検出し、端末ID、Codex/Claude Skill、開始・終了プロトコル、ログオン時と1分ごとの同期タスクを登録します。定期同期はWindows Script Host経由で非表示実行されるため、コンソールウィンドウを表示しません。Task Hubはタスクバー右端の通知領域へ常駐し、ダブルクリックで画面を開き、右クリックで即時同期または終了できます。スタートメニューの `Visitas Task Hub` からも開けます。UIサーバーは `127.0.0.1:7700` にだけbindします。

`ssh_event_bridge.py` も配置されます。Mac側の毎分ジョブは、公開鍵SSH経由でこのbridgeを呼び出し、Boxイベントの不足分だけを双方向交換できます。bridgeは月ディレクトリ直下のJSONイベントだけを許可し、既存ファイルの上書きと同名・異ハッシュの競合を拒否します。

テスト:

```powershell
Set-Location .\app
py -3 -m unittest discover -s tests -v
```
