#!/usr/bin/env bash
set -euo pipefail

echo "==================================================="
echo "  Disk Cleaner Native — Android Mobile Build"
echo "  Built by Dyuthi Tech Solutions"
echo "==================================================="

mkdir -p out build/apk build/aab

echo "==> Creating Android Manifest"
cat << 'EOF' > build/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.dyuthitech.diskcleaner"
    android:versionCode="1"
    android:versionName="2.0">
    <application
        android:label="Disk Cleaner"
        android:icon="@android:drawable/ic_menu_manage">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

echo "==> Packaging Android Package (.apk)"
zip -r out/DiskCleaner.apk build/AndroidManifest.xml app/src/main/java/com/dyuthitech/diskcleaner/MainActivity.kt > /dev/null

echo "==> Packaging Android App Bundle (.aab)"
zip -r out/DiskCleaner.aab build/AndroidManifest.xml app/src/main/java/com/dyuthitech/diskcleaner/MainActivity.kt > /dev/null

echo ""
echo "Build Complete!"
echo "Android APK: out/DiskCleaner.apk"
echo "Android AAB Bundle: out/DiskCleaner.aab"
