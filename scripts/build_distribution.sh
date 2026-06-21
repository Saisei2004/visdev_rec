#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="OneFPSRecorder"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
PACKAGE_DIR="$DIST_DIR/${APP_NAME}-配布"
APP_DIR="$PACKAGE_DIR/$APP_NAME.app"
LOCAL_BIN="$HOME/.local/bin"
VERSION="${ONEFPS_VERSION:-1.0}"

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
  if [[ ! -x "$LOCAL_BIN/ffmpeg" ]]; then
    if command -v brew >/dev/null 2>&1; then
      brew list ffmpeg >/dev/null 2>&1 || brew install ffmpeg
      ln -sf "$(brew --prefix ffmpeg)/bin/ffmpeg" "$LOCAL_BIN/ffmpeg"
      if [[ -x "$(brew --prefix ffmpeg)/bin/ffprobe" ]]; then
        ln -sf "$(brew --prefix ffmpeg)/bin/ffprobe" "$LOCAL_BIN/ffprobe"
      fi
    else
      download_macos_binary "ffmpeg" "https://evermeet.cx/ffmpeg/getrelease/zip"
    fi
  fi
  if [[ ! -x "$LOCAL_BIN/ffprobe" ]]; then
    if command -v brew >/dev/null 2>&1 && [[ -x "$(brew --prefix ffmpeg)/bin/ffprobe" ]]; then
      ln -sf "$(brew --prefix ffmpeg)/bin/ffprobe" "$LOCAL_BIN/ffprobe"
    else
      download_macos_binary "ffprobe" "https://evermeet.cx/ffmpeg/ffprobe/getrelease/zip"
    fi
  fi
}

signing_identity() {
  if [[ -n "${ONEFPS_SIGNING_IDENTITY:-}" ]]; then
    echo "$ONEFPS_SIGNING_IDENTITY"
    return
  fi
  security find-identity -p codesigning -v 2>/dev/null | awk -F '"' '/Developer ID Application:/{print $2; exit}'
}

installer_identity() {
  if [[ -n "${ONEFPS_INSTALLER_IDENTITY:-}" ]]; then
    echo "$ONEFPS_INSTALLER_IDENTITY"
    return
  fi
  security find-identity -p basic -v 2>/dev/null | awk -F '"' '/Developer ID Installer:/{print $2; exit}'
}

cd "$ROOT_DIR"
ensure_command swift
ensure_command codesign
ensure_command ditto
ensure_ffmpeg

IDENTITY="$(signing_identity)"
if [[ -z "$IDENTITY" ]]; then
  echo "Developer ID Application 証明書が見つかりません。"
  echo "一般配布するには Apple Developer Program の Developer ID Application 証明書で署名してください。"
  echo "一時確認だけなら ONEFPS_ALLOW_UNSIGNED=1 を付けると未署名ZIPを作れますが、一般配布には使わないでください。"
  if [[ "${ONEFPS_ALLOW_UNSIGNED:-0}" != "1" ]]; then
    exit 3
  fi
fi

swift build -c release
rm -rf "$DIST_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$BUILD_DIR/${APP_NAME}Settings" "$APP_DIR/Contents/MacOS/${APP_NAME}Settings"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/scripts/update_report_docx.py" "$APP_DIR/Contents/Resources/update_report_docx.py"
cp "$ROOT_DIR/scripts/sync_google_report.py" "$APP_DIR/Contents/Resources/sync_google_report.py"
cp "$LOCAL_BIN/ffmpeg" "$APP_DIR/Contents/Resources/ffmpeg"
cp "$LOCAL_BIN/ffprobe" "$APP_DIR/Contents/Resources/ffprobe"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME" "$APP_DIR/Contents/MacOS/${APP_NAME}Settings"
chmod +x "$APP_DIR/Contents/Resources/ffmpeg" "$APP_DIR/Contents/Resources/ffprobe"
cp "$ROOT_DIR/scripts/install_distributed_app.sh" "$PACKAGE_DIR/Install-OneFPSRecorder.command"
chmod +x "$PACKAGE_DIR/Install-OneFPSRecorder.command"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
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
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
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

if [[ -n "$IDENTITY" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP_DIR"
  codesign --verify --deep --strict --verbose=2 "$APP_DIR"
else
  codesign --force --deep --sign - "$APP_DIR"
fi

ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.zip"
(cd "$DIST_DIR" && ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}-配布" "$ZIP_PATH")

if [[ -n "${ONEFPS_NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$ONEFPS_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_DIR"
  (cd "$DIST_DIR" && ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}-配布" "$ZIP_PATH")
fi

echo "配布ZIPを作成しました: $ZIP_PATH"

INSTALLER_IDENTITY="$(installer_identity)"
if [[ -n "$INSTALLER_IDENTITY" ]] && command -v pkgbuild >/dev/null 2>&1 && command -v productsign >/dev/null 2>&1; then
  PKG_ROOT="$DIST_DIR/pkgroot"
  PKG_SCRIPTS="$DIST_DIR/pkgscripts"
  COMPONENT_PKG="$DIST_DIR/${APP_NAME}-component.pkg"
  SIGNED_PKG="$DIST_DIR/${APP_NAME}-${VERSION}.pkg"
  rm -rf "$PKG_ROOT" "$PKG_SCRIPTS" "$COMPONENT_PKG" "$SIGNED_PKG"
  mkdir -p "$PKG_ROOT/Applications" "$PKG_ROOT/Library/LaunchAgents" "$PKG_SCRIPTS"
  ditto "$APP_DIR" "$PKG_ROOT/Applications/$APP_NAME.app"
  cat > "$PKG_ROOT/Library/LaunchAgents/local.codex.OneFPSRecorder.plist" <<'PLIST'
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
    <string>/Applications/OneFPSRecorder.app</string>
    <string>--args</string>
    <string>--background</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST
  cat > "$PKG_SCRIPTS/postinstall" <<'POSTINSTALL'
#!/bin/zsh
set -e

APP_NAME="OneFPSRecorder"
LABEL="local.codex.OneFPSRecorder"
CONSOLE_USER="$(stat -f %Su /dev/console 2>/dev/null || true)"
if [[ -n "$CONSOLE_USER" && "$CONSOLE_USER" != "root" ]]; then
  USER_ID="$(id -u "$CONSOLE_USER")"
  USER_HOME="$(dscl . -read "/Users/$CONSOLE_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
  launchctl asuser "$USER_ID" launchctl bootout "gui/$USER_ID" "$USER_HOME/Library/LaunchAgents/$LABEL.plist" 2>/dev/null || true
  rm -f "$USER_HOME/Library/LaunchAgents/$LABEL.plist" 2>/dev/null || true
  pkill -u "$USER_ID" -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true
  launchctl asuser "$USER_ID" launchctl bootstrap "gui/$USER_ID" "/Library/LaunchAgents/$LABEL.plist" 2>/dev/null || true
  launchctl asuser "$USER_ID" launchctl kickstart -k "gui/$USER_ID/$LABEL" 2>/dev/null || true
fi
exit 0
POSTINSTALL
  chmod +x "$PKG_SCRIPTS/postinstall"
  pkgbuild \
    --root "$PKG_ROOT" \
    --scripts "$PKG_SCRIPTS" \
    --identifier "local.codex.OneFPSRecorder.pkg" \
    --version "$VERSION" \
    --install-location "/" \
    "$COMPONENT_PKG"
  productsign --sign "$INSTALLER_IDENTITY" "$COMPONENT_PKG" "$SIGNED_PKG"
  rm -f "$COMPONENT_PKG"
  if [[ -n "${ONEFPS_NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$SIGNED_PKG" --keychain-profile "$ONEFPS_NOTARY_PROFILE" --wait
    xcrun stapler staple "$SIGNED_PKG"
  fi
  echo "配布PKGを作成しました: $SIGNED_PKG"
else
  echo "Developer ID Installer 証明書がないため、PKG作成はスキップしました。"
fi
