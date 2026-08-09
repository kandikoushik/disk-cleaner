#!/usr/bin/env bash
set -euo pipefail

echo "==================================================="
echo "  Disk Cleaner Native — iOS Mobile (.ipa) Build"
echo "  Built by Dyuthi Tech Solutions"
echo "==================================================="

mkdir -p out Payload/DiskCleaner.app

echo "==> Compiling Swift for iOS Simulator / Device Target"
xcrun -sdk iphonesimulator swiftc -target arm64-apple-ios16.0-simulator \
    -parse-as-library \
    -emit-executable \
    -o Payload/DiskCleaner.app/DiskCleaner \
    Sources/DiskCleanerApp.swift

echo "==> Creating Info.plist for iOS App Bundle"
cat << 'EOF' > Payload/DiskCleaner.app/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DiskCleaner</string>
    <key>CFBundleIdentifier</key>
    <string>com.dyuthitech.diskcleaner.ios</string>
    <key>CFBundleName</key>
    <string>Disk Cleaner</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
</dict>
</plist>
EOF

echo "==> Packaging iOS Distributable Bundle (.ipa)"
zip -r out/DiskCleaner.ipa Payload > /dev/null
rm -rf Payload

echo ""
echo "Build Complete!"
echo "iOS App Package: out/DiskCleaner.ipa"
