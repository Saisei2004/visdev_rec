#!/bin/zsh
set -euo pipefail

APP_NAME="OneFPSRecorder"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP="$SCRIPT_DIR/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"
AGENT_DIR="$HOME/Library/LaunchAgents"
AGENT_PLIST="$AGENT_DIR/local.codex.OneFPSRecorder.plist"

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "$APP_NAME.app が見つかりません。配布フォルダを展開した状態で、このインストーラを実行してください。"
  exit 1
fi

if find "$HOME/Movies/1FPS録画" -maxdepth 3 -path '*/.frames-*/*' -type f -mmin -2 2>/dev/null | grep -q .; then
  echo "直近2分以内に更新された一時フレームがあります。録画停止と保存完了を待ってから、もう一度実行してください。"
  echo "古い一時フレームはアプリ起動時に自動復旧します。"
  exit 2
fi

mkdir -p "$INSTALL_DIR" "$AGENT_DIR"
launchctl bootout "gui/$(id -u)" "$AGENT_PLIST" 2>/dev/null || true
pkill -f "$INSTALLED_APP/Contents/MacOS/$APP_NAME" 2>/dev/null || true
sleep 1
if [[ -d "$INSTALLED_APP" ]]; then
  chmod -R u+w "$INSTALLED_APP" 2>/dev/null || true
fi
rm -rf "$INSTALLED_APP"
ditto "$SOURCE_APP" "$INSTALLED_APP"
xattr -dr com.apple.quarantine "$INSTALLED_APP" 2>/dev/null || true

if [[ -d "$SCRIPT_DIR/Agent-Skills/visitas-daily-report" ]]; then
  for target in "$HOME/.agents/skills/visitas-daily-report" "$HOME/.claude/skills/visitas-daily-report"; do
    mkdir -p "$(dirname "$target")"
    rm -rf "$target"
    ditto "$SCRIPT_DIR/Agent-Skills/visitas-daily-report" "$target"
  done
fi

cat > "$AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>local.codex.OneFPSRecorder</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-gj</string>
    <string>$INSTALLED_APP</string>
    <string>--args</string>
    <string>--background</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST

launchctl bootstrap "gui/$(id -u)" "$AGENT_PLIST"
launchctl kickstart -k "gui/$(id -u)/local.codex.OneFPSRecorder"

echo "インストールして起動しました: $INSTALLED_APP"
echo "メニューバーに 1FPS が表示されます。初回だけ macOS の画面収録許可を有効にしてください。"
