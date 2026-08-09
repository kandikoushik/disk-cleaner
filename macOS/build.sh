#!/bin/bash
# Builds the fully native "Disk Cleaner.app" and a distributable DMG.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/out"
APP="$OUT/Disk Cleaner.app"
VERSION="2.0"

rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> Compiling Swift"
swiftc -O -whole-module-optimization \
  -target arm64-apple-macosx13.0 \
  -framework AppKit -framework SwiftUI \
  "$HERE"/Sources/*.swift \
  -o "$APP/Contents/MacOS/DiskCleaner"

echo "==> Assembling bundle"
if [ -f "$HERE/Resources/AppIcon.icns" ]; then
  cp "$HERE/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
elif [ -f "$HOME/disk-cleaner/build/icon.icns" ]; then
  cp "$HOME/disk-cleaner/build/icon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

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
  <key>CFBundleIconFile</key>          <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>    <string>13.0</string>
  <key>NSHighResolutionCapable</key>   <true/>
  <key>LSApplicationCategoryType</key> <string>public.app-category.utilities</string>
  <key>NSHumanReadableCopyright</key>  <string>Local utility. No network access.</string>
</dict>
</plist>
PLIST

# A stable signing identity keeps macOS privacy grants across rebuilds; an
# ad-hoc signature changes hash every build and resets them every time.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -m1 -o '"[^"]*"' | tr -d '"')}"
if [ -n "$IDENTITY" ]; then
  echo "==> Signing as: $IDENTITY"
  codesign --force --deep --options runtime -s "$IDENTITY" "$APP"
else
  echo "==> Signing (ad-hoc — permissions reset on each rebuild)"
  codesign --force --deep -s - "$APP"
fi
codesign --verify --deep --strict "$APP" && echo "    signature ok"

echo "==> Building DMG"
STAGE="$OUT/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/Read me first.txt" <<'TXT'
Disk Cleaner 2.0 — native

INSTALL
  Drag "Disk Cleaner" onto the Applications folder shown here.

FIRST LAUNCH
  Right-click the app -> Open -> Open. Once only.

FULL DISK ACCESS (recommended)
  System Settings -> Privacy & Security -> Full Disk Access -> add Disk Cleaner.
  One grant, instead of a prompt for every folder it scans.

WHAT IT DOES
  Finds reclaimable caches and build artifacts, shows exactly what would be
  deleted and how big each item is, and removes only what you tick.

      safe     pure caches, regenerate on their own
      rebuild  regenerates, but costs a re-download or a rebuild
      review   your own data - never selected automatically

  Explore lists your biggest folders, largest files, and files untouched for a
  year. Activity lists listening ports and heavy processes.

SAFETY
  Never touches anything outside your home folder. Never quits a protected
  system process or one belonging to another user. No network access at all.

REQUIREMENTS
  macOS 13 or later. No other dependencies - this is a single native binary.
TXT

DMG="$OUT/DiskCleaner-$VERSION.dmg"
hdiutil create -volname "Disk Cleaner" -srcfolder "$STAGE" -ov -format UDZO -quiet "$DMG"
rm -rf "$STAGE"

echo
echo "App: $APP"
echo "DMG: $DMG"
du -sh "$APP" | awk '{print "     bundle: "$1}'
