@echo off
echo ===================================================
echo   Disk Cleaner Native — Windows Build Script
echo   Built by Dyuthi Tech Solutions
echo ===================================================
echo.

if not exist out mkdir out

echo ==> Compiling Windows Standalone Executable (DiskCleaner.exe)
csc /target:winexe /r:System.Windows.Forms.dll,System.Drawing.dll,System.Net.Http.dll /out:out\DiskCleaner.exe src\Program.cs src\CleanerEngine.cs

echo ==> Copying UI Assets to output directory
copy src\App.html out\
copy src\style.css out\
copy src\app.js out\
copy src\catalog.json out\

echo ==> Building Installable EXE (DiskCleaner-Windows-Setup.exe)
makensis installer.nsi

echo ==> Bundling Native Windows Executable Package (ZIP fallback)
powershell -Command "Compress-Archive -Path out\* -DestinationPath out\DiskCleaner-Windows-v3.0.zip -Force"

echo.
echo Build Complete!
echo Executable: out\DiskCleaner.exe
echo Installer: out\DiskCleaner-Windows-Setup.exe
echo Package: out\DiskCleaner-Windows-v2.0.zip
