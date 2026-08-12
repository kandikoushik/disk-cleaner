# Changelog

All notable changes to **Disk Cleaner** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v4.0.0] - 2026-08-12

### 🚀 Added
- **Menu Bar Status Item (`macOS/Sources/App.swift`)**: Native macOS MenuBarExtra widget with live disk space monitoring and one-click quick clean shortcuts.
- **Dynamic Custom JSON Plugin Target Engine (`PluginLoader.swift`)**: Scans and dynamically loads user custom cleanup rules from `~/.config/disk-cleaner/plugins/*.json`.
- **Docker & Podman Volume Purger (`Catalog.swift`)**: Target rules for dangling volumes, stopped containers, and build caches (`docker system prune -af --volumes`).
- **Xcode Simulator & Device Wiper (`Catalog.swift`)**: Deep purge for Xcode Swift Previews, Simulator caches, and iOS/watchOS/tvOS DeviceSupport files.
- **Homebrew Cask Orphan Cleaner (`Catalog.swift`)**: Auto-purge orphaned Homebrew cask archives and downloads.
- **Windows WinSxS DISM Component Store Analyzer (`windows/src/CleanerEngine.cs`)**: Added Component Store DISM analysis to `DiskCleaner.exe`.
- **Background Auto-Cleanup Daemon Installer (`scripts/install_auto_clean_daemon.sh`)**: LaunchAgent script for weekly automated `.safe` tier cleaning.

### ⚡ Changed
- Upgraded version string to **`4.0.0`** (`DiskCleaner-4.0.dmg`).
- Updated `ROADMAP.md` marking all milestones as **✅ Completed**.
- Updated website and `README.md` download links to target `v4.0.0`.

---

## [v3.0.0] - 2026-08-12

### 🚀 Added
- Apache 2.0 Open Source Licensing (`LICENSE`).
- Multiplatform Ecosystem engines (macOS Swift, Windows `DiskCleaner.exe`, iOS, Android).
- AI & MCP Model Context Protocol integration (`llms.txt`, `llms-full.txt`, `MCP_GUIDE.md`).
- GitHub Pages landing page (`https://kandikoushik.github.io/disk-cleaner/`).
- GitHub Actions CI/CD workflows (`ci.yml`, `release.yml`).

---

## [v2.0.0] - 2026-08-09

### 🚀 Added
- Single native Swift 5.10 binary replacing v1 Python server shell.
- Parallel directory sizing engine utilizing Swift `TaskGroup` across CPU cores.
- 3-Pass streaming duplicate finder (Byte size → 64KB Head Hash → Full SHA-256).

---

## [v1.0.0] - 2026-08-01

### 🚀 Added
- Initial hybrid prototype (Python HTTP server behind WKWebView window).
