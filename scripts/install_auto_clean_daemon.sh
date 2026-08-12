#!/bin/bash
# Disk Cleaner — Background Auto-Clean LaunchAgent Installer
set -euo pipefail

PLIST_NAME="local.diskcleaner.autoclean.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$LAUNCH_AGENTS_DIR/$PLIST_NAME"
APP_BINARY="$HOME/disk-cleaner/out/Disk Cleaner.app/Contents/MacOS/DiskCleaner"

echo "=========================================="
echo "  Disk Cleaner — Auto-Clean Daemon Setup  "
echo "=========================================="
echo

mkdir -p "$LAUNCH_AGENTS_DIR"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>local.diskcleaner.autoclean</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_BINARY</string>
        <string>--clean-safe</string>
        <string>--confirm</string>
    </array>
    <key>StartInterval</key>
    <integer>604800</integer> <!-- Run once per week (7 days) -->
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "✅ Installed LaunchAgent at $PLIST_PATH"
echo "   Configured to run weekly background safe cleanup."
