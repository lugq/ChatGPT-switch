#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ChatGPT-switch"
PRODUCT_NAME="CodexSwitch"
OUTPUT_DIR="$ROOT_DIR/outputs"
APP_DIR="$OUTPUT_DIR/$APP_NAME.app"
ICON_SOURCE="$ROOT_DIR/assets/AppIcon.jpg"
MENU_BAR_ICON_SOURCE="$ROOT_DIR/assets/MenuBarIcon.png"
ICON_NAME="AppIcon"
ZIP_PATH="$OUTPUT_DIR/$APP_NAME.zip"
PKG_PATH="$OUTPUT_DIR/$APP_NAME.pkg"
BUILD_WORK_DIR=""
BUILD_APP_DIR=""
CONTENTS_DIR=""
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR=""
PKG_ROOT=""

cleanup() {
  if [[ -n "$BUILD_WORK_DIR" ]]; then
    rm -rf "$BUILD_WORK_DIR"
  fi
  if [[ -n "$PKG_ROOT" ]]; then
    rm -rf "$(dirname "$PKG_ROOT")"
  fi
}
trap cleanup EXIT

cd "$ROOT_DIR"

swift build -c release --product "$PRODUCT_NAME"

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "error: missing app icon source at $ICON_SOURCE" >&2
  exit 1
fi

if [[ ! -f "$MENU_BAR_ICON_SOURCE" ]]; then
  echo "error: missing menu bar icon source at $MENU_BAR_ICON_SOURCE" >&2
  exit 1
fi

if ! command -v iconutil >/dev/null 2>&1; then
  echo "error: iconutil is required to create the app icon" >&2
  exit 1
fi

BUILD_WORK_DIR="$(mktemp -d)"
BUILD_APP_DIR="$BUILD_WORK_DIR/$APP_NAME.app"
CONTENTS_DIR="$BUILD_APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$BUILD_WORK_DIR/$ICON_NAME.iconset"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"
cp "$MENU_BAR_ICON_SOURCE" "$RESOURCES_DIR/MenuBarIcon.png"

cp "$ROOT_DIR/.build/release/$PRODUCT_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

ROUNDED_ICON_SOURCE="$BUILD_WORK_DIR/$ICON_NAME.png"
swift "$ROOT_DIR/scripts/make_rounded_icon.swift" "$ICON_SOURCE" "$ROUNDED_ICON_SOURCE" 1024

for icon_size in 16 32 128 256 512; do
  sips -s format png -z "$icon_size" "$icon_size" "$ROUNDED_ICON_SOURCE" --out "$ICONSET_DIR/icon_${icon_size}x${icon_size}.png" >/dev/null
  retina_size=$((icon_size * 2))
  sips -s format png -z "$retina_size" "$retina_size" "$ROUNDED_ICON_SOURCE" --out "$ICONSET_DIR/icon_${icon_size}x${icon_size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/$ICON_NAME.icns"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>ChatGPT-switch</string>
  <key>CFBundleIdentifier</key>
  <string>com.lugq.ChatGPTSwitch</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>ChatGPT-switch</string>
  <key>CFBundleDisplayName</key>
  <string>ChatGPT-switch</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$BUILD_APP_DIR" >/dev/null 2>&1 || true
fi

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$BUILD_APP_DIR" >/dev/null 2>&1 || true
fi

rm -f "$ZIP_PATH" "$PKG_PATH"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$BUILD_APP_DIR" "$ZIP_PATH"

APP_OUTPUT_READY=0
if rm -rf "$APP_DIR" >/dev/null 2>&1; then
  ditto --norsrc "$BUILD_APP_DIR" "$APP_DIR"
  APP_OUTPUT_READY=1
else
  echo "warning: could not replace $APP_DIR; pkg and zip were built from a clean temporary app bundle" >&2
fi

if ! command -v pkgbuild >/dev/null 2>&1; then
  echo "error: pkgbuild is required to create the installer package" >&2
  exit 1
fi

PKG_WORK_DIR="$(mktemp -d)"
PKG_ROOT="$PKG_WORK_DIR/root"
PKG_COMPONENTS="$PKG_WORK_DIR/components.plist"
PKG_APPLICATIONS_DIR="$PKG_ROOT/Applications"
mkdir -p "$PKG_APPLICATIONS_DIR"
ditto --norsrc "$BUILD_APP_DIR" "$PKG_APPLICATIONS_DIR/$APP_NAME.app"

cat > "$PKG_COMPONENTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
  <dict>
    <key>BundleHasStrictIdentifier</key>
    <true/>
    <key>BundleIsRelocatable</key>
    <false/>
    <key>BundleIsVersionChecked</key>
    <false/>
    <key>BundleOverwriteAction</key>
    <string>upgrade</string>
    <key>RootRelativeBundlePath</key>
    <string>Applications/ChatGPT-switch.app</string>
  </dict>
</array>
</plist>
PLIST

COPYFILE_DISABLE=1 pkgbuild \
  --root "$PKG_ROOT" \
  --install-location "/" \
  --component-plist "$PKG_COMPONENTS" \
  --identifier "com.lugq.ChatGPTSwitch.pkg" \
  --version "0.1.0" \
  "$PKG_PATH"

if [[ "$APP_OUTPUT_READY" == "1" ]]; then
  echo "$APP_DIR"
fi
echo "$ZIP_PATH"
echo "$PKG_PATH"
