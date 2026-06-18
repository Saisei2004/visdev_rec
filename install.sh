#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="OneFPSRecorder"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"
AGENT_DIR="$HOME/Library/LaunchAgents"
AGENT_PLIST="$AGENT_DIR/local.codex.OneFPSRecorder.plist"
LOCAL_BIN="$HOME/.local/bin"

ensure_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 が見つかりません。Xcode Command Line Tools を入れてから再実行してください。"
    echo "インストール: xcode-select --install"
    exit 1
  fi
}

download_macos_binary() {
  local name="$1"
  local url="$2"
  local zip_path="/tmp/${name}-onefps.zip"
  local unzip_dir="/tmp/${name}-onefps"

  rm -rf "$zip_path" "$unzip_dir"
  mkdir -p "$unzip_dir"
  curl -L "$url" -o "$zip_path"
  ditto -x -k "$zip_path" "$unzip_dir"
  local binary_path
  binary_path="$(find "$unzip_dir" -type f -name "$name" -perm -111 | head -1)"
  if [[ -z "$binary_path" ]]; then
    echo "$name の取得に失敗しました。"
    exit 1
  fi
  mkdir -p "$LOCAL_BIN"
  cp "$binary_path" "$LOCAL_BIN/$name"
  chmod +x "$LOCAL_BIN/$name"
}

ensure_ffmpeg() {
  mkdir -p "$LOCAL_BIN"
  if [[ -x "$LOCAL_BIN/ffmpeg" ]]; then
    return
  fi

  if command -v brew >/dev/null 2>&1; then
    brew list ffmpeg >/dev/null 2>&1 || brew install ffmpeg
    ln -sf "$(brew --prefix ffmpeg)/bin/ffmpeg" "$LOCAL_BIN/ffmpeg"
    if [[ -x "$(brew --prefix ffmpeg)/bin/ffprobe" ]]; then
      ln -sf "$(brew --prefix ffmpeg)/bin/ffprobe" "$LOCAL_BIN/ffprobe"
    fi
    return
  fi

  download_macos_binary "ffmpeg" "https://evermeet.cx/ffmpeg/getrelease/zip"
  if [[ ! -x "$LOCAL_BIN/ffprobe" ]]; then
    download_macos_binary "ffprobe" "https://evermeet.cx/ffmpeg/ffprobe/getrelease/zip"
  fi
}

cd "$ROOT_DIR"
ensure_command swift
ensure_command codesign
ensure_ffmpeg
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$BUILD_DIR/${APP_NAME}Settings" "$APP_DIR/Contents/MacOS/${APP_NAME}Settings"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>OneFPSRecorder</string>
  <key>CFBundleIdentifier</key>
  <string>local.codex.OneFPSRecorder</string>
  <key>CFBundleName</key>
  <string>OneFPSRecorder</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSScreenCaptureUsageDescription</key>
  <string>画面を1FPSで録画し、~/Movies/1FPS録画 に保存します。</string>
</dict>
</plist>
PLIST

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALLED_APP"
cp -R "$APP_DIR" "$INSTALLED_APP"
xattr -dr com.apple.quarantine "$INSTALLED_APP" 2>/dev/null || true
SIGNING_IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null | awk -F '\"' '/Apple Development:/{print $2; exit}')"
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --force --deep --sign "$SIGNING_IDENTITY" "$INSTALLED_APP"
  echo "Signed with: $SIGNING_IDENTITY"
else
  codesign --force --deep --sign - "$INSTALLED_APP"
  echo "Signed with: ad-hoc"
fi

mkdir -p "$AGENT_DIR"
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
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST
pkill -f "$INSTALLED_APP/Contents/MacOS/$APP_NAME" 2>/dev/null || true
launchctl bootout "gui/$(id -u)" "$AGENT_PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$AGENT_PLIST"
launchctl kickstart -k "gui/$(id -u)/local.codex.OneFPSRecorder"

echo "インストールして起動しました: $INSTALLED_APP"
echo "ログイン時の自動起動: $AGENT_PLIST"
echo "操作方法: メニューバー項目と録画中パネル"
echo "保存先: $HOME/Movies/1FPS録画/YYYY-MM/MMDD/MMDD_保存名.mp4"
echo "区間ログ: $HOME/Movies/1FPS録画/YYYY-MM/MMDD/録画区間ログ-YYYY-MM-DD.txt"
echo "日別合計: $HOME/Movies/1FPS録画/YYYY-MM/日別合計作業時間-YYYY-MM.txt"
