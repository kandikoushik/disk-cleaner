# <img src="docs/app-icon.png" width="42" height="42" align="center" alt="Disk Cleaner Logo"> Disk Cleaner — The Ultimate Open-Source Multiplatform System Utility

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B_Native_Swift-lightgrey.svg)](macOS/)
[![Windows](https://img.shields.io/badge/Windows-DiskCleaner.exe-blue.svg)](windows/)
[![iOS](https://img.shields.io/badge/iOS-17.0%2B_SwiftUI-orange.svg)](iOS/)
[![Android](https://img.shields.io/badge/Android-Kotlin_Clean-green.svg)](android/)
[![AI & MCP Ready](https://img.shields.io/badge/AI_%26_MCP-llms.txt-purple.svg)](MCP_GUIDE.md)
[![Open Source](https://img.shields.io/badge/Open_Source-%E2%9D%A4%EF%B8%8F_Community-ff69b4.svg)](https://github.com/kandikoushik/disk-cleaner)

**Disk Cleaner** is the **best open-source multiplatform disk cleanup, storage optimizer, and system utility**. Engineered for **macOS, Windows, iOS, and Android**, it delivers blazing-fast parallel directory sizing, content-hash duplicate detection, deep app uninstallation, and system maintenance — all with **zero background telemetry, zero tracking, and 100% privacy**.

---

## 🚀 Downloads & Quick Install

- 🍏 **macOS Universal Binary (DMG)**: [<img src="https://img.shields.io/badge/Download_DiskCleaner--2.0.dmg-10b981?style=flat-square&logo=apple&logoColor=white">](https://github.com/kandikoushik/disk-cleaner/releases/download/v2.0.0/DiskCleaner-2.0.dmg)
- 🪟 **Windows Portable Executable (`DiskCleaner.exe`)**: [<img src="https://img.shields.io/badge/Build_Windows_DiskCleaner.exe-06b6d4?style=flat-square&logo=windows&logoColor=white">](windows/README.md)
- 🤖 **AI & MCP Agent Specifications**: [`MCP_GUIDE.md`](MCP_GUIDE.md) | [`llms.txt`](llms.txt) | [`llms-full.txt`](llms-full.txt)

---

## 🌐 Multiplatform Ecosystem

Disk Cleaner provides tailored native engines across all major desktop and mobile operating systems:

| Platform | Executable / Artifact | Tech Stack | Status | Key Capabilities |
| :--- | :--- | :--- | :---: | :--- |
| **macOS** | `DiskCleaner-2.0.dmg` / `Disk Cleaner.app` | Pure Swift 5.10 & SwiftUI | 🟢 **Stable v2.0** | ~30 Smart targets, TaskGroup parallel sizing, 3-pass SHA-256 duplicate hashing, Liquid Glass UI, LaunchServices & Spotlight maintenance. |
| **Windows** | `DiskCleaner.exe` / `Setup.exe` | C# (.NET Framework) + HTML/CSS/JS | 🟢 **Stable** | Standalone Windows `.exe` binary, Windows Temp, Prefetch, WinSxS cleanup engine, PowerShell script integration. |
| **iOS** | SwiftUI App Bundle | Swift / SwiftUI | 🟡 **Active** | Mobile photo & duplicate media detection, cache analyzer, low-memory diagnostic tools. |
| **Android** | `app-release.apk` | Kotlin / Android SDK | 🟡 **Active** | Junk APK purge, temporary app cache cleanup, storage breakdown analyzer. |

---

## 🤖 AI Assistants & MCP Integration

Disk Cleaner natively supports **AI discovery and Model Context Protocol (MCP)** automation:

- **`llms.txt` Standard**: [`llms.txt`](llms.txt) for LLM search engines & AI assistants.
- **Full Context Specification**: [`llms-full.txt`](llms-full.txt) containing data schemas, target rules, and security policies.
- **MCP Server Guide**: [`MCP_GUIDE.md`](MCP_GUIDE.md) detailing MCP tool schemas (`scan_disk_space`, `list_cleanup_targets`, `find_duplicate_files`) and JSON CLI flags (`--scan --json`).

---

## 🌟 Why Disk Cleaner is the Best Open-Source Cleaner

Most disk cleaners are bloated, require monthly subscriptions, or collect personal data in the background. **Disk Cleaner** provides a completely free, transparent, open-source native alternative designed for performance and safety.

### 🥊 Comparison: Disk Cleaner vs. Proprietary Alternatives

| Feature | 🚀 **Disk Cleaner (Open Source)** | 🛑 CleanMyMac X | 📁 DaisyDisk | ⚙️ OnyX | 🧹 CCleaner |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Open Source (Apache 2.0)** | ✅ **100% Free & Open** | ❌ Proprietary ($39.95/yr) | ❌ Proprietary ($9.99) | 🆓 Freeware | ❌ Freemium |
| **Multiplatform Support** | ✅ **macOS, Windows, iOS, Android** | ❌ macOS Only | ❌ macOS Only | ❌ macOS Only | ⚠️ Windows/Mac |
| **Standalone Windows `.exe`** | ✅ **Built-in `DiskCleaner.exe`** | ❌ No | ❌ No | ❌ No | ⚠️ Installed Only |
| **AI & MCP Agent Support** | ✅ **`llms.txt` + MCP Server** | ❌ No | ❌ No | ❌ No | ❌ No |
| **Privacy & Zero Telemetry** | ✅ **Zero Network Access** | ❌ Background Analytics | ❓ Minimal | ✅ Local Only | ❌ Background Services |
| **Parallel TaskGroup Speed** | ✅ **Multi-threaded Swift** | ❓ Single/Multi | ⚡ Multi-threaded | 🐌 Sequential | 🐌 Slow |
| **Triple-Pass Duplicate Hash** | ✅ **Byte → Head → SHA-256** | ✅ Included | ❌ No | ❌ No | ⚠️ Basic |

---

## ⚡ Core macOS Features & Capabilities

### 🧹 1. Smart Clean (~30 High-Yield Targets)
Cleans up gigabytes of accumulated junk grouped by explicit risk levels:
- 🟢 **Safe**: Pure caches (Xcode DerivedData, CocoaPods, SwiftPM, Homebrew cache, browser caches, system logs) that auto-regenerate.
- 🟡 **Rebuild**: Download caches and compilation artifacts (npm/yarn/pnpm cache, Cargo cache, Docker containers, Go build caches) that cost a re-download or re-compile.
- 🔴 **Review**: User files, Downloads folder items, and Trash — never automatically auto-selected.

### 🔍 2. Disk Space Explorer
Visualizes storage hogs instantly:
- Highlights the **largest files** and **biggest directories** across your drive.
- Identifies untouched files **older than 1 year** for quick archiving or removal.

### 📦 3. Deep App Uninstaller
Finds all leftover traces that dragging an app to the Trash leaves behind:
- Application Support folders
- Application Caches & Saved States
- Sandbox Containers & Preferences
- Background LaunchAgents and LaunchDaemons

### 👯 4. High-Performance Duplicate Finder
Employs a **three-pass streaming deduplication engine** designed for maximum speed:
1. **Pass 1**: Instant grouping by exact file size.
2. **Pass 2**: 64 KB head hash comparison (filters out 95%+ non-duplicates without reading whole files).
3. **Pass 3**: Full SHA-256 hash validation for guaranteed 100% match accuracy.

---

## 🛡️ Ironclad Safety Guarantees

1. **`Cleaner.allowed()` Safety Chokepoint**: Every deletion request passes through a central security gate that strictly rejects paths outside your `$HOME` directory and protects `$HOME` root itself.
2. **Trash-First Deletion**: All deleted items move to the macOS **Trash** by default, allowing simple drag-and-drop recovery if needed.
3. **Protected Process Shield**: Prevents terminating root processes, system daemons, or background services owned by other system users.
4. **Offline & Sandboxed**: Contains **zero network calls**, analytics, or telemetry code.

---

## 💻 Building from Source

### macOS (`Disk Cleaner.app` & DMG)
```bash
git clone https://github.com/kandikoushik/disk-cleaner.git
cd disk-cleaner
./build.sh
```

### Windows (`DiskCleaner.exe`)
```cmd
cd windows
build.bat
```

---

## 📄 License

Distributed under the **Apache License 2.0**. See [`LICENSE`](LICENSE) for details.

---

<p align="center">
  Developed with ❤️ by <a href="https://github.com/kandikoushik">Koushik Kandi</a> and Open Source Contributors.
</p>
