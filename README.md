# VisDev Recorder

Macの画面を1FPSで軽く記録するメニューバー常駐アプリです。音声なし、低めの解像度、日別MP4への追記、月別ログ保存に寄せています。

## 最短インストール

```zsh
git clone https://github.com/Saisei2004/visdev_rec.git
cd visdev_rec
./install.sh
```

インストール後は `~/Applications/OneFPSRecorder.app` に入り、ログイン時に自動起動します。メニューバーに `1FPS` が出れば起動済みです。

初回だけ macOS の `画面収録` 許可が必要です。聞かれたら `OneFPSRecorder` を許可し、macOSが求めた場合はアプリを開き直してください。

## 使い方

- メニューバーの `1FPS` から `録画開始` / `録画停止`
- `保存フォルダを開く` で保存先をFinder表示
- `設定...` で保存名、録画中パネル、月間スコアを変更
- 録画中は小さな前面パネルからも停止可能

## 保存先

```text
~/Movies/1FPS録画/YYYY-MM/MMDD_保存名.mp4
~/Movies/1FPS録画/YYYY-MM/録画区間ログ-YYYY-MM.txt
~/Movies/1FPS録画/YYYY-MM/日別合計作業時間-YYYY-MM.txt
```

例:

```text
~/Movies/1FPS録画/2026-06/0616_松田.mp4
```

同じ日の録画は1つのMP4へ後ろに追記されます。統合済みの一時動画は自動で削除します。

## 設定

- `保存名`: ファイル名の `MMDD_保存名.mp4` の保存名部分。ファイル名に使えない文字は `-` に置換し、最大48文字に収めます
- `録画中パネルを表示する`: 赤い録画中パネルの表示切り替え
- `月間スコアを表示する`: 月内の録画時間から算出した金額を表示
- `係数`: 1時間あたりの金額。標準は `2000`
- `月末ライン`: 月内の目標金額。標準は `100000`
- `目標達成時に光らせる`: 月間スコアが月末ライン以上になると録画中パネルが発光

## コメント

録画開始時のコメントは時間帯とその日の作業時間で変わります。

- 朝: `朝から偉いですね。` など
- 昼: `ここからが本番。` など
- 夜: `今日も頑張ってるね。` など
- 作業時間: 1時間、4時間、8時間を超えると候補が変化
- `Visitas`、`JUST DO IT`、画面録画システムらしいコメントも混ざります

表示コメントは最大28文字に収めています。

## 仕様

- 1秒1コマ
- MP4 / H.264
- 音声なし
- 出力解像度: `960x600`
- 複数モニター時はマウスカーソルがある画面を録画
- 約1時間ごとに自動保存して一時フレームを削除
- ffmpegは `~/.local/bin/ffmpeg` を使用

## インストーラが行うこと

- Swiftでアプリをビルド
- ffmpegがなければ準備
  - Homebrewがある場合: `brew install ffmpeg`
  - Homebrewがない場合: Mac用ffmpegバイナリを `~/.local/bin` へ取得
- `~/Applications/OneFPSRecorder.app` へ配置
- LaunchAgentを作成してログイン時自動起動

## 確認

```zsh
ps -axo pid,%mem,rss,args | rg OneFPSRecorder
tail -n 50 ~/Library/Logs/1FPS録画.log
```

## アンインストール

```zsh
launchctl unload ~/Library/LaunchAgents/local.codex.OneFPSRecorder.plist 2>/dev/null || true
rm -f ~/Library/LaunchAgents/local.codex.OneFPSRecorder.plist
rm -rf ~/Applications/OneFPSRecorder.app
```

録画済みファイルを消す場合だけ、以下も実行します。

```zsh
rm -rf ~/Movies/1FPS録画
```

## Visitas リポジトリへ導入する場合

Visitas 本体へこの録画システムを入れる場合は、Visitas の開発規約に合わせて **Issue 起点、専用 worktree、main 向け PR** で進めます。調査時点の Visitas 規約では、`AGENTS.md`、`CLAUDE.md`、`.claude/rules/branch-isolation.md`、`.github/PULL_REQUEST_TEMPLATE.md` が入口です。

### 確認した Visitas 側ルール

- 既定ブランチは `main`
- 作業は `main` 直作業ではなく、必ず専用 `git worktree`
- ベースは `origin/main`
- ブランチ命名は以下が基本
  - 機能追加: `feature/<issue-number>-<short-name>`
  - バグ修正: `fix/<issue-number>-<short-name>`
  - ドキュメントのみ: `docs/<issue-number>-<short-name>` または既存の `docs/*` 系に合わせる
- 1 Issue = 1 PR
- PR の base は `main`
- PR タイトルは Conventional Commits 形式
  - 例: `docs(devtools): add VisDev Recorder setup guide (#1234)`
  - 例: `feat(devtools): add VisDev Recorder installer (#1234)`
- `git add .` / `git add -A` は使わず、必ずファイル指定で stage
- `force push` / `--amend` は原則禁止
- AI agent はデプロイ、マージ、production 反映を勝手に実行しない
- PR テンプレートに従い、概要、関連 Issue、変更内容、テスト計画、デプロイ Tier を書く

### 推奨導入方針

このアプリは macOS のメニューバー常駐ツールで、Visitas の Go / Next.js / Cloud Run 本体とは別物です。したがって、Visitas 側では以下のどちらかが安全です。

1. **docs-only 導入**
   - Visitas に `docs/ops/VISDEV_RECORDER.md` などを追加
   - このリポジトリ `https://github.com/Saisei2004/visdev_rec` の clone/install 手順を記載
   - Visitas 本体のビルド、CI、デプロイに影響しない

2. **tools 配下へ vendor 導入**
   - Visitas に `tools/visdev-recorder/` としてこのソースを配置
   - Visitas checkout だけで `tools/visdev-recorder/install.sh` を実行できる
   - CI 対象外にするか、必要な場合だけ Swift build を追加する

まずは **docs-only 導入** を推奨します。理由は、ブランチ切替・worktree削除・Visitas の CI/CD と録画ツールを分離できるためです。録画アプリ本体は `~/Applications/OneFPSRecorder.app` に入り、保存データは `~/Movies/1FPS録画` に置かれるので、Visitas のブランチを切り替えても通常どおり使えます。

### Visitas での作業手順

Issue が `#1234` の場合:

```bash
cd /path/to/Visitas
git fetch origin main
git status --short
git worktree add /tmp/visitas-visdev-recorder -b docs/1234-visdev-recorder origin/main
cd /tmp/visitas-visdev-recorder
git branch --show-current
```

docs-only 導入:

```bash
mkdir -p docs/ops
$EDITOR docs/ops/VISDEV_RECORDER.md
```

`docs/ops/VISDEV_RECORDER.md` に書く内容の例:

```md
# VisDev Recorder

Visitas 開発中の画面を 1FPS で軽く記録する macOS メニューバーアプリ。

## インストール

\`\`\`zsh
git clone https://github.com/Saisei2004/visdev_rec.git
cd visdev_rec
./install.sh
\`\`\`

## 保存先

\`\`\`text
~/Movies/1FPS録画/YYYY-MM/MMDD_保存名.mp4
~/Movies/1FPS録画/YYYY-MM/録画区間ログ-YYYY-MM.txt
~/Movies/1FPS録画/YYYY-MM/日別合計作業時間-YYYY-MM.txt
\`\`\`

## Visitas ブランチ切替時の扱い

インストール後のアプリは `~/Applications/OneFPSRecorder.app`、録画データは `~/Movies/1FPS録画` にあるため、Visitas の worktree やブランチを削除しても録画環境は残る。
```

tools 導入にする場合:

```bash
mkdir -p tools
git clone https://github.com/Saisei2004/visdev_rec.git /tmp/visdev_rec
rsync -a --delete --exclude .git --exclude .build --exclude '*.app' /tmp/visdev_rec/ tools/visdev-recorder/
```

### Visitas PR 前チェック

docs-only の場合:

```bash
git status --short
git diff -- docs/ops/VISDEV_RECORDER.md
git add docs/ops/VISDEV_RECORDER.md
git commit -m "docs(devtools): add VisDev Recorder setup guide"
git push -u origin docs/1234-visdev-recorder
gh pr create --base main --title "docs(devtools): add VisDev Recorder setup guide (#1234)"
```

tools 導入の場合:

```bash
swift build -c release --package-path tools/visdev-recorder
git status --short
git add tools/visdev-recorder/Package.swift \
  tools/visdev-recorder/README.md \
  tools/visdev-recorder/install.sh \
  tools/visdev-recorder/Sources
git commit -m "feat(devtools): add VisDev Recorder installer"
git push -u origin feature/1234-visdev-recorder
gh pr create --base main --title "feat(devtools): add VisDev Recorder installer (#1234)"
```

PR テンプレートでは以下のように書きます。

- 関連 Issue: `Closes #1234` または `Refs #1234`
- テスト計画:
  - docs-only: `docs/ops/VISDEV_RECORDER.md` の手順確認
  - tools 導入: `swift build -c release --package-path tools/visdev-recorder`
  - 実機確認: `./install.sh`、メニューバー起動、短時間録画、保存先確認
- デプロイ Tier:
  - docs-only / macOS devtool 追加なら基本 `Tier 1` 相当、Cloud Run / Firebase / DB 変更なし

### 注意

- Visitas の `main` / `production` へ直接 push しない
- `git add .` は使わない
- 録画ファイル、`.frames-*`、`*.app`、`.build/` は Visitas に commit しない
- worktree を削除しても、インストール済みアプリと録画データは残る
- Visitas の CI/CD やデプロイは、このツール追加では触らない
