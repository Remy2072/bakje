#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP=build.noindex/Bakje.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O main.swift -o "$APP/Contents/MacOS/Bakje"
FONTS=~/Documents/Projecten/Servers/omelette-shop/static/fonts
cp "$FONTS"/SuisseIntl-Regular.woff2 "$APP/Contents/Resources/"
if [[ ! -f AppIcon.icns ]]; then
  TMP=$(mktemp -d)
  swiftc icon.swift -o "$TMP/makeicon"
  "$TMP/makeicon" "$TMP/AppIcon.icns"
  iconutil -c icns "$TMP/AppIcon.iconset" -o AppIcon.icns
  rm -rf "$TMP"
fi
cp AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Bakje</string>
  <key>CFBundleIdentifier</key><string>nl.rmd.bakje</string>
  <key>CFBundleName</key><string>Bakje</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"
echo "Gebouwd: $PWD/$APP"
if [[ "${1:-}" == "--install" ]]; then
  pkill -x Bakje || true
  ditto "$APP" /Applications/Bakje.app
  open /Applications/Bakje.app
  echo "Geinstalleerd: /Applications/Bakje.app"
fi
