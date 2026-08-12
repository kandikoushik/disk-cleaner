# Disk Cleaner for Windows (`DiskCleaner.exe`)

High-performance native Windows storage cleanup engine built in C# (.NET Framework / .NET Core) with HTML/CSS/JS WebView desktop interface and PowerShell automation scripts.

---

## 📦 Output Executables & Packages

When built using `build.bat`, the following artifacts are generated in `windows/out/`:

- **`DiskCleaner.exe`**: Standalone portable Windows executable. No installer needed; double-click to run instantly.
- **`DiskCleaner-Windows-Setup.exe`**: NSIS installer executable for clean installation into `C:\Program Files\DiskCleaner`.
- **`DiskCleaner-Windows-v2.0.zip`**: Portable ZIP archive containing `DiskCleaner.exe` and required catalog assets.

---

## 🛠️ Building `DiskCleaner.exe` on Windows

### Quick Build (`build.bat`)

Open Developer Command Prompt for Visual Studio or Command Prompt and run:

```cmd
cd windows
build.bat
```

### Manual Compilation using C# Compiler (`csc.exe`)

```cmd
csc /target:winexe /r:System.Windows.Forms.dll,System.Drawing.dll,System.Net.Http.dll /out:out\DiskCleaner.exe src\Program.cs src\CleanerEngine.cs
copy src\App.html out\
copy src\style.css out\
copy src\app.js out\
copy src\catalog.json out\
```

---

## ⚙️ Features & Cleanup Targets

- **Windows Temp Directories**: `C:\Windows\Temp`, `%USERPROFILE%\AppData\Local\Temp`
- **Prefetch & Crash Dumps**: `C:\Windows\Prefetch`, `%USERPROFILE%\AppData\Local\CrashDumps`
- **Windows Update Cleanup**: `C:\Windows\SoftwareDistribution\Download`
- **Browser Caches**: Chrome, Edge, Firefox, Brave cache purges
- **Development Caches**: `.nuget` cache, `npm-cache`, `pip` cache

---

## 📄 License

Distributed under the **Apache License 2.0**. See [`LICENSE`](../LICENSE) for details.
