---
name: visitas-daily-report
description: Use when Saisei asks Codex or Claude to draft, review, bulk-submit, or post OneFPSRecorder videos, Drive monthly reports, Slack #日報 posts, or to use registered Visitas sources and the personal Visitas Task Hub for a daily report.
---

# Visitas Daily Report

OneFPSRecorder、Drive月報、Visitas Slack `#日報`、個人用Visitas Task Hubを、同じ日付と同じ下書きで安全に連携する。

## Source of truth

最初に次を実行して、アプリが登録している現在の参照先と未投稿日を読む。

```bash
APP="$HOME/Applications/OneFPSRecorder.app/Contents/MacOS/OneFPSRecorder"
if [ ! -x "$APP" ]; then APP="/Applications/OneFPSRecorder.app/Contents/MacOS/OneFPSRecorder"; fi
"$APP" --report-config
"$APP" --report-candidates "$(date +%Y-%m)"
```

`--report-config` が返す値を優先する。標準の参照元は次の4つ。

1. Visitas Slack と `#日報` の本人スレッド
2. Gmail の Notta 議事録検索
3. `~/visitas-tasks/taskctl.py` が同期する Task Hub
4. 設定された GitHub Issues リポジトリ

Visitasタスクに触れる場合は、毎回 `AGENT.md` と `KNOWLEDGE.md` を読み、実行中のエージェント名で `taskctl.py --actor <codex|claude> sync` と `brief` を実行する。Box内の追記イベントが正典であり、`tasks.json` や別のMarkdown台帳を直接編集しない。

設定画面の「日報・参照元...」に登録された追加参照も読む。参照できないソースは推測で埋めず、`not checked` と明示する。SlackやGmailの生本文は、日報に必要な最小限だけ要約し、リポジトリや恒久ファイルへ保存しない。

## Permission gate

ユーザーが同じ依頼の中で各外部操作を明示的に許可していない場合、下書きを作る前後のどちらでもよいが、外部書き込みの前に必ず停止して、次の3点をそのまま質問する。

1. 今日の動画を投稿して良いですか。
2. Driveの報告書を自動で書いて良いですか。
3. Slackの日報を自動で書いて良いですか。

3つは独立した許可として扱う。「全部投稿して」のように3つすべてが明示されている場合だけ再質問を省略できる。返答が無い、曖昧、またはSkillが無言で呼ばれただけの場合は、下書きと候補表示までに留め、動画アップロード、Drive更新、Slack投稿を行わない。

月単位の一括処理でも、許可は処理対象日と宛先を示して1回確認する。投稿済みの可能性がある日は、ローカル提出状態と投稿先を確認し、二重投稿しない。

## Draft workflow

1. `--report-candidates YYYY-MM` から動画があり未完了の日と作業時間を取得する。
2. 対象日のSlack、Notta、Task Hub、GitHub Issuesを確認し、確認できた事実だけを日報にまとめる。
3. 各日について、担当者、業務プラン、やったこと、詰まった/判断待ち、明日、状態、補足、動画リンクの全項目を用意する。
4. 根拠の衝突や不確実性があれば、断定せず下書き内または結果に明示する。
5. 実行後は成功した宛先と失敗した宛先を日付ごとに返す。

Slack本文は、ライブの `#日報` 案内に合わせて次の形にする。

```text
📅 M/D <本人のSlackメンション>
✅ やった
・（PRリンク / Refs #Issue番号）
🚧 詰まった / 判断待ち
・（無ければ「なし」）
➡️ 明日
・（次の作業）
```

`#日報` ではチャンネル直下ではなく、本人の日報スレッドへの返信として投稿する。Slack connectorを使う場合は本人スレッドと本人IDを解決し、`thread_ts` を付ける。bare `@name` を通知可能なメンションだと見なさない。Webhookを使う場合は、設定済みの個人スレッドIDが必須。

## Execute through OneFPSRecorder

`references/request-schema.json` と同じJSONを一時ファイルに作り、許可された宛先だけを `true` にして実行する。

```bash
"$APP" --submit-report-json /path/to/request.json
```

- 動画またはDriveを許可しない場合は、それぞれ `uploadVideoToDrive` / `updateDriveReport` を `false` にする。
- Slack connectorから投稿する場合は `postToSlack:false` でローカル/Drive処理を終え、本人スレッドへ返信する。成功後だけ次を実行する。

```bash
"$APP" --mark-slack-posted-date YYYY-MM-DD
```

- Incoming Webhookと個人スレッドIDが設定済みで、ユーザーがSlack投稿を許可した場合だけ `postToSlack:true` を使える。
- 一部失敗時に成功済みの宛先を再投稿しない。候補JSONの `submissionState` を確認して再開する。
- JSON一時ファイルに秘密、Slack生本文、メール生本文を入れない。

## Visitas Task Hub updates

日報の根拠から新しいタスクや進捗差分が見つかった場合は、書き込み前に `taskctl.py --actor <codex|claude> sync` を実行し、`AGENT.md` の競合回避ルールに従う。

- 重複を `source_ref` で確認する。
- 根拠が弱い新規項目は `inbox` にする。
- 完了根拠なしに `done` にしない。
- タスク削除は必ず別途確認する。
- 追加・状態変更・メモはすべて `taskctl.py` 経由で行う。
- 最後に `handoff` へ日報処理の結果と次の1手を記録し、`sync` する。
- 個人Task HubをVisitas本体リポジトリへコミットしない。

最後に `checked / not checked` の参照元、作成した日付、各宛先の実行結果、Task Hubの変更有無を簡潔に報告する。
