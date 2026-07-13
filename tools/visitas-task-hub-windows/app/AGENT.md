# Visitas Task Hub v2 — Codex / Claude 共通プロトコル

Visitas関連の作業では、CodexもClaudeもこのHubを共通の進捗記録として使う。
正典はBox内の追記専用イベント群で、`~/visitas-tasks/tasks.json` は表示・互換用のローカルキャッシュである。

## 必須ワークフロー

1. 作業開始前に、実行環境に応じて次のどちらかを実行する。

   ```bash
   ~/visitas-tasks/taskctl.py --actor codex sync
   ~/visitas-tasks/taskctl.py --actor codex brief
   # Claudeでは --actor claude
   ```

   Windowsでは次を使う。

   ```powershell
   py -3 "$env:USERPROFILE\visitas-tasks\taskctl.py" --actor codex sync
   py -3 "$env:USERPROFILE\visitas-tasks\taskctl.py" --actor codex brief
   # Claudeでは --actor claude
   ```

2. 関係するタスクがなければ追加する。着手・待ち・ブロック・完了も必ずCLI経由で記録する。

   ```bash
   ~/visitas-tasks/taskctl.py --actor codex add "タスク名" --next "具体的な次の1手"
   ~/visitas-tasks/taskctl.py --actor codex start TASK_ID
   ~/visitas-tasks/taskctl.py --actor codex block TASK_ID "理由"
   ~/visitas-tasks/taskctl.py --actor codex done TASK_ID
   ```

3. 作業終了時に、別エージェント・別PCがそのまま続けられる引き継ぎを記録する。

   ```bash
   ~/visitas-tasks/taskctl.py --actor codex handoff \
     --task TASK_ID \
     --summary "行ったこと" \
     --next "次に行うこと" \
     --files "/absolute/path/to/file" \
     --verification "確認結果"
   ~/visitas-tasks/taskctl.py --actor codex sync
   ```

   Windowsでも同じ引数を `py -3 "$env:USERPROFILE\visitas-tasks\taskctl.py"` に渡す。

## データの扱い

- `tasks.json` やBox内の `data/events/**/*.json` を直接編集・削除しない。変更は `taskctl.py` を使う。
- 同じIssueは `source_ref` で一意に扱い、重複タスクを作らない。
- 完了の根拠がないものを `done` にしない。推定期限を入れない。
- Slack本文、メール本文、医療情報、認証情報をタスクに複製しない。要点・参照先・次の1手だけを記録する。
- Visitas本体のリポジトリには、この個人用Hubをコミットしない。

## 情報源

標準の棚卸し対象は、GitHub担当Issue、SlackのVisitas関連チャンネル、GmailのNotta通知、タスクボード／計画文書。
確認した情報源ごとに `source-check` を記録し、未確認を確認済みのように扱わない。

```bash
~/visitas-tasks/taskctl.py --actor codex github-import
~/visitas-tasks/taskctl.py --actor codex source-check slack checked --note "確認範囲"
```

実装・評価・デプロイ等の背景が必要な場合は、`~/visitas-tasks/KNOWLEDGE.md` も読む。
