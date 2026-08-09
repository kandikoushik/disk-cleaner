@echo off
echo ===================================================
echo   Disk Cleaner Native — Windows Build Script
echo   Built by Dyuthi Tech Solutions
echo ===================================================
echo.

if not exist out mkdir out

echo ==> Compiling Windows CleanerEngine.cs
csc /target:library /out:out\CleanerEngine.dll src\CleanerEngine.cs

echo ==> Bundling Native Windows Executable
powershell -Command "Compress-Archive -Path src\* -DestinationPath out\DiskCleaner-Windows-v2.0.zip -Force"

echo.
echo Build Complete!
echo Package: out\DiskCleaner-Windows-v2.0.zip
