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

if find "$HOME/Movies/1FPS録画" -maxdepth 3 -type d -name '.frames-*' 2>/dev/null | grep -q .; then
  echo "保存前の一時フレームが残っています。録画停止と保存完了を待ってから、もう一度実行してください。"
  exit 2
fi

mkdir -p "$INSTALL_DIR" "$AGENT_DIR"
launchctl bootout "gui/$(id -u)" "$AGENT_PLIST" 2>/dev/null || true
pkill -f "$INSTALLED_APP/Contents/MacOS/$APP_NAME" 2>/dev/null || true
rm -rf "$INSTALLED_APP"
ditto "$SOURCE_APP" "$INSTALLED_APP"
xattr -dr com.apple.quarantine "$INSTALLED_APP" 2>/dev/null || true

cat > "$AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>local.codex.OneFPSRecorder</string>
  <key>ProgramArguments</key>
  <array>
    <string>$INSTALLED_APP/Contents/MacOS/$APP_NAME</string>
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
