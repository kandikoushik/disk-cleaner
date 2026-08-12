# 🚀 Disk Cleaner — The Ultimate Open-Source Native Disk Cleanup & System Utility

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS_14.0%2B-lightgrey.svg)](macOS/)
[![Language](https://img.shields.io/badge/Language-Swift_5.10-orange.svg)](macOS/Sources/)
[![Architecture](https://img.shields.io/badge/Architecture-Native_Single_Binary-brightgreen.svg)](macOS/Sources/)
[![Open Source](https://img.shields.io/badge/Open_Source-%E2%9D%A4%EF%B8%8F_Community-ff69b4.svg)](https://github.com/kandikoushik/disk-cleaner)

**Disk Cleaner** is the **best open-source native disk cleanup, storage optimizer, and system utility** for macOS. Engineered in pure **Swift & SwiftUI**, it delivers blazing-fast parallel directory sizing, content-hash duplicate detection, deep app uninstallation, and system maintenance — all in a lightweight single binary with **zero telemetry, zero dependencies, and 100% privacy**.

---

## 🌟 Why Disk Cleaner is the Best Open-Source Mac Cleaner

Most Mac cleaners are bloated, require monthly subscriptions, or collect personal data in the background. **Disk Cleaner** was born out of necessity when a developer Mac hit **249 MB free space** — recovering **41+ GB** on its very first pass.

### 🥊 Comparison: Disk Cleaner vs. Proprietary Alternatives

| Feature | 🚀 **Disk Cleaner (Open Source)** | 🛑 CleanMyMac X | 📁 DaisyDisk | ⚙️ OnyX | 🧹 CCleaner |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Open Source (Apache 2.0)** | ✅ **100% Free & Open** | ❌ Proprietary ($39.95/yr) | ❌ Proprietary ($9.99) | 🆓 Freeware | ❌ Freemium |
| **Privacy & Zero Telemetry** | ✅ **Zero Network Access** | ❌ Background Analytics | ❓ Minimal | ✅ Local Only | ❌ Background Services |
| **Native Swift & SwiftUI UI** | ✅ **Liquid Glass / Native** | 🎨 Custom GUI | 🎨 Custom GUI | ⚙️ Native | 📦 Electron / Heavy |
| **Parallel TaskGroup Sizing** | ✅ **Multi-threaded Swift** | ❓ Single/Multi | ⚡ Multi-threaded | 🐌 Sequential | 🐌 Slow |
| **Triple-Pass Duplicate Hash** | ✅ **Byte → Head → SHA-256** | ✅ Included | ❌ No | ❌ No | ⚠️ Basic |
| **App Uninstaller & Residue** | ✅ **Caches, Containers, LaunchAgents** | ✅ Included | ❌ No | ❌ No | ✅ Basic |
| **System Maintenance Scripts** | ✅ **Spotlight, DNS, LaunchServices** | ✅ Included | ❌ No | ✅ Advanced | ⚠️ Limited |
| **Listening Ports & Activity** | ✅ **Guard-Quit Heavy Apps** | ❌ No | ❌ No | ❌ No | ❌ No |

---

## ⚡ Core Features & Capabilities

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

### 🛠️ 5. One-Click System Maintenance
Automates essential macOS system maintenance utilities:
- Rebuild Launch Services database
- Re-index Spotlight search engine
- Flush local DNS caches (`dscacheutil`)
- Reset Quick Look icon & thumbnail caches

### 📊 6. Activity & Network Port Guard
- Displays active listening network ports and high-memory/CPU processes.
- Includes a **guarded process termination** system that prevents accidental quitting of vital system services.

---

## 🛡️ Ironclad Safety Guarantees

Security and data safety are built directly into the core engine architecture:

1. **`Cleaner.allowed()` Safety Chokepoint**: Every deletion request passes through a central security gate that strictly rejects paths outside your `$HOME` directory and protects `$HOME` root itself.
2. **Trash-First Deletion**: All deleted items move to the macOS **Trash** by default, allowing simple drag-and-drop recovery if needed. Permanent deletion is strictly opt-in.
3. **Protected Process Shield**: Prevents terminating root processes, system daemons, or background services owned by other system users.
4. **Transparent Size Confirmations**: Displays explicit confirmation dialogs detailing exact byte counts before performing actions.
5. **Offline & Sandboxed**: Contains **zero network calls**, analytics, or telemetry code.

---

## 🏗️ Architecture & High-Performance Design

- **Multi-Threaded Swift Sizing**: Replaces single-threaded `du -sk` shell calls with in-process `FileManager` + `URLResourceValues` parallelized using `TaskGroup` across all CPU cores.
- **Conditional Liquid Glass UI**: Uses native macOS 14+ `Glass` materials with soft background backdrops while gracefully falling back to structured opaque cards on older macOS versions.
- **Single Binary Footprint**: Runs as 1 single native process consuming ~119 MB RAM (down from Python WKWebView v1 which took 5 processes and 196 MB).

---

## 💻 Building from Source

### Requirements
- macOS 14.0 (Sonoma) or newer
- Xcode 15+ or Swift 5.10+ command-line tools

### Quick Build
Clone the repository and run the build script:

```bash
git clone https://github.com/kandikoushik/disk-cleaner.git
cd disk-cleaner
./build.sh
```

The output app bundle and DMG installer will be generated in `out/`:
- `out/Disk Cleaner.app`
- `out/DiskCleaner-2.0.dmg`

> **Note on Code Signing**: `build.sh` automatically uses your local developer certificate or falls back to standard ad-hoc signing. Grant **Full Disk Access** once in *System Settings → Privacy & Security* for uninterrupted disk scanning.

---

## 📂 Project Structure

```
disk-cleaner/
├── macOS/
│   └── Sources/
│       ├── Model.swift       # Data models, risk definitions & target types
│       ├── Catalog.swift     # Built-in cleanup targets database (~30 rules)
│       ├── Scanner.swift     # Multi-threaded parallel directory scanner
│       ├── Engine.swift      # Deletion engine, explore algorithms & activity
│       ├── Uninstall.swift   # App residue finder & duplicate hash engine
│       ├── AppState.swift    # Reactive Observable state management
│       ├── Design.swift      # Glassmorphism design system & chart views
│       ├── CleanView.swift   # Smart Clean interface
│       └── OtherViews.swift  # Explore, Apps, Duplicates, Maintenance & Activity views
├── android/                  # Android companion module
├── iOS/                      # iOS companion module
├── windows/                  # Windows build automation scripts
├── LICENSE                   # Apache License 2.0
└── README.md                 # Documentation
```

---

## 🤝 Contributing

Contributions are welcome! Whether you want to add new cleanup targets, improve scanning speed, translate the UI, or expand multiplatform support:

1. Fork the Repository.
2. Create a Feature Branch (`git checkout -b feature/awesome-target`).
3. Commit your changes (`git commit -m 'feat: add Xcode Simulator cache target'`).
4. Push to the Branch (`git push origin feature/awesome-target`).
5. Open a Pull Request.

---

## 📄 License

Distributed under the **Apache License 2.0**. See [`LICENSE`](LICENSE) for details.

---

<p align="center">
  Developed with ❤️ by <a href="https://github.com/kandikoushik">Koushik Kandi</a> and Open Source Contributors.
</p>
