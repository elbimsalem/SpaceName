#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SpaceName"
BUNDLE_ID="de.synkmedia.spacename"
VERSION="1.0.0"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="${ROOT}/${APP_NAME}.app"
CONTENTS="${APP}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RES_DIR="${CONTENTS}/Resources"

echo "==> Building (release)…"
swift build -c release

BIN="${ROOT}/.build/release/${APP_NAME}"
[[ -f "${BIN}" ]] || { echo "error: binary not found at ${BIN}" >&2; exit 1; }

echo "==> Assembling ${APP_NAME}.app…"
rm -rf "${APP}"
mkdir -p "${MACOS_DIR}" "${RES_DIR}"
cp "${BIN}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

if [[ -f "${ROOT}/icon.png" ]]; then
  bash "${ROOT}/make-icon.sh" "${ROOT}/icon.png" "${RES_DIR}/AppIcon.icns"
fi

cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>               <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>        <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>         <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>         <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>            <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key> <string>${VERSION}</string>
    <key>CFBundlePackageType</key>        <string>APPL</string>
    <key>CFBundleIconFile</key>           <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>     <string>15.0</string>
    <key>LSUIElement</key>                <true/>
    <key>NSHighResolutionCapable</key>    <true/>
    <key>NSPrincipalClass</key>           <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc codesigning…"
codesign --force --sign - "${APP}"
codesign --verify --verbose "${APP}"
echo "==> Done: ${APP}"
