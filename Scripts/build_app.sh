#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

sign_identity="${IFM_APP_IDENTITY:--}"

swift build -c release --product IdeaFermentationMachine

app="dist/IdeaFermentationMachine.app"
contents="$app/Contents"
rm -rf "$app"
mkdir -p "$contents/MacOS" "$contents/Resources"

cp .build/release/IdeaFermentationMachine "$contents/MacOS/IdeaFermentationMachine"
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$contents/Resources/AppIcon.icns"
fi

cat > "$contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>IdeaFermentationMachine</string>
  <key>CFBundleIdentifier</key>
  <string>com.chrisdimarco.idea-fermentation-machine</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Idea Fermentation Machine</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

printf 'APPL????' > "$contents/PkgInfo"
codesign_args=(--force --deep --sign "$sign_identity")
if [[ "$sign_identity" != "-" ]]; then
  codesign_args+=(--options runtime --timestamp)
fi
codesign "${codesign_args[@]}" "$app" >/dev/null
echo "$PWD/$app"
