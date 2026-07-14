# Windows report core

macOS版OneFPSRecorderと同じ候補・依頼・提出状態JSONを扱うPython 3コアです。外部処理は既定でdry-runであり、実行には `--execute` と宛先別 `--permission` の両方が必要です。

```powershell
py -3 reportctl.py --report-config
py -3 reportctl.py --report-candidates 2026-07
py -3 reportctl.py --submit-report-json request.json --dry-run
```

実投稿の直前にUIまたは担当エージェントが動画・Drive・Slackを個別確認し、許可済みのものだけを渡します。Slackは設定した `#日報` の本人 `thread_ts` が無い限り拒否され、チャンネル直下へは投稿しません。Webhookは `credentialctl.py set-slack-webhook` でWindows Credential Managerへ保存します。
