# Visitas Practical Task Hub v2

見栄えより「今やる1件」「次の1手」「止まっている理由」「Codex/Claudeの引き継ぎ」を優先した個人用タスク管理です。

## 開く

```bash
bash ~/visitas-tasks/start.sh
```

ブラウザで `http://127.0.0.1:7700/` が開きます。追加・編集・着手・完了・ブロック、GitHub担当Issueの取り込み、Codex/Claudeへの引き継ぎが画面からできます。

Windowsでは `%USERPROFILE%\visitas-tasks\Start-Visitas-Task-Hub.cmd` を実行します。インストールは `Install-Visitas-Task-Hub.ps1` がBoxルートを検出し、同期タスクとSkillを登録します。

## 端末間の同期

- 正典: Boxの `Codex Transfers/Visitas Task Hub Shared/data/events/`
- 各PCの表示用キャッシュ: `~/visitas-tasks/tasks.json`
- 1分ごとに自動同期し、UIも30秒ごとに再読込します。
- 変更は端末ごとの追記ファイルなので、同時更新でも相手の進捗を上書きしません。

もう一台のMacではBox内の `Visitas Task Hub Shared/Install-Visitas-Task-Hub.command` を一度開いてください。
Windowsではリポジトリ内の `tools/visitas-task-hub-windows/Install-Visitas-Task-Hub.ps1` を一度実行してください。

## AIとの共有

CodexとClaudeは作業開始時に同期と要約を行い、終了時にタスク状態と引き継ぎを保存します。手動操作用の例:

```bash
~/visitas-tasks/taskctl.py --actor human brief
~/visitas-tasks/taskctl.py --actor human list
~/visitas-tasks/taskctl.py --actor human add "新しい作業" --next "最初の一手"
```

詳細は `AGENT.md`、Visitas固有の背景は `KNOWLEDGE.md` を参照してください。
