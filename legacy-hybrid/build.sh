#!/bin/bash
# Builds "Disk Cleaner.app" and a distributable DMG.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$(dirname "$HERE")"
OUT="$HERE/out"
APP="$OUT/Disk Cleaner.app"
VERSION="1.0"

rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> Compiling"
swiftc -O -target arm64-apple-macosx12.0 \
  -framework AppKit -framework WebKit \
  "$HERE/main.swift" -o "$APP/Contents/MacOS/DiskCleaner"

echo "==> Assembling bundle"
cp "$SRC/server.py" "$SRC/index.html" "$APP/Contents/Resources/"
cp "$HERE/icon.icns" "$APP/Contents/Resources/icon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>              <string>Disk Cleaner</string>
  <key>CFBundleDisplayName</key>       <string>Disk Cleaner</string>
  <key>CFBundleIdentifier</key>        <string>local.diskcleaner</string>
  <key>CFBundleVersion</key>           <string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundlePackageType</key>       <string>APPL</string>
  <key>CFBundleExecutable</key>        <string>DiskCleaner</string>
  <key>CFBundleIconFile</key>          <string>icon</string>
  <key>LSMinimumSystemVersion</key>    <string>12.0</string>
  <key>NSHighResolutionCapable</key>   <true/>
  <key>NSHumanReadableCopyright</key>  <string>Local utility. No network access.</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key> <true/>
  </dict>
</dict>
</plist>
PLIST

# Sign with a real identity when one exists. This matters beyond Gatekeeper:
# macOS ties privacy grants (Documents, Downloads, other apps' data, Full Disk
# Access) to the signing identity. An ad-hoc signature is identified by its code
# hash, which changes on EVERY rebuild — so each rebuild looks like a new app and
# every permission you granted is discarded. A stable certificate keeps them.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -m1 -o '"[^"]*"' | tr -d '"')}"

if [ -n "$IDENTITY" ]; then
  echo "==> Signing as: $IDENTITY"
  codesign --force --deep --options runtime -s "$IDENTITY" "$APP"
else
  echo "==> Signing (ad-hoc — permissions will reset on each rebuild)"
  codesign --force --deep -s - "$APP"
fi
codesign --verify --deep --strict "$APP" && echo "    signature ok"

echo "==> Building DMG"
STAGE="$OUT/stage"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

cat > "$STAGE/Read me first.txt" <<'TXT'
Disk Cleaner
============

INSTALL
  Drag "Disk Cleaner" onto the Applications folder shown here.

FIRST LAUNCH
  macOS blocks apps from unidentified developers. This one is signed
  ad-hoc (built on your own machine), so the first time:

      Right-click the app  ->  Open  ->  Open

  You only have to do this once. After that, launch it normally.

WHAT IT DOES
  Scans for reclaimable caches and build artifacts, shows you exactly
  what would be deleted and how big each item is, and removes only the
  ones you tick. Items are grouped:

      safe     pure caches, regenerate on their own
      rebuild  regenerates, but costs a re-download or a rebuild
      review   your own data - never selected automatically

  Nothing is deleted until you press Clean and confirm.

SAFETY
  The app refuses to touch any path outside your home folder. Its UI is
  served by a helper on 127.0.0.1 only, on a random port, and the helper
  is shut down when you quit the app. Nothing is sent off the machine.

REQUIREMENTS
  Python 3 (preinstalled on macOS with the Xcode Command Line Tools).
  If it is missing, run:  xcode-select --install
TXT

DMG="$OUT/DiskCleaner-$VERSION.dmg"
hdiutil create -volname "Disk Cleaner" -srcfolder "$STAGE" \
  -ov -format UDZO -quiet "$DMG"
rm -rf "$STAGE"

echo
echo "App: $APP"
echo "DMG: $DMG"
du -h "$DMG" | cut -f1 | sed 's/^/     /'
