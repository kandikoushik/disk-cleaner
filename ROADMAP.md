# Disk Cleaner — Open Source Project Roadmap

This roadmap tracks feature additions, multiplatform expansions, and technical milestones for **Disk Cleaner**.

---

## 🚀 Version 4.0.0 — Ecosystem Major Release (LIVE ✅)

All planned roadmap features have been built, verified, and released in **Version 4.0.0**:

- ✅ **Menu Bar Status Extra Widget**: Native macOS MenuBarExtra widget with live disk space monitoring and one-click quick clean shortcuts.
- ✅ **Dynamic Custom JSON Plugin Target Engine**: Dynamic custom rule loader scanning `~/.config/disk-cleaner/plugins/*.json`.
- ✅ **Docker & Podman Volume Purger**: Target rules for dangling volumes, stopped containers, and build caches (`docker system prune`).
- ✅ **Xcode Simulator & Device Wiper**: Deep purge for Xcode Swift Previews, Simulator caches, and iOS/watchOS/tvOS DeviceSupport files.
- ✅ **Homebrew Cask Orphan Cleaner**: Auto-purge orphaned Homebrew cask archives and downloads.
- ✅ **Windows WinSxS DISM Component Store Analyzer**: Added Component Store DISM analysis to `DiskCleaner.exe`.
- ✅ **Background Auto-Cleanup Daemon**: LaunchAgent script for weekly automated `.safe` tier cleaning (`scripts/install_auto_clean_daemon.sh`).
- ✅ **AI & MCP Model Context Protocol Support**: Full `llms.txt` standard and machine-readable `--scan --json` CLI integration.
- ✅ **Multiplatform Native Engines**: macOS (Swift/SwiftUI), Windows (`DiskCleaner.exe`), iOS, and Android.
- ✅ **Automated GitHub Actions CI/CD Pipelines**: Automated multiplatform compilation tests and release packaging.

---

## 🔮 Future Vision (v4.x / Future Releases)

- [ ] **Unified Multiplatform P2P Sync**: Local encrypted device sync for user preferences across Mac, Windows, iPhone, and Android.
- [ ] **Sunburst Storage TreeMap Visualizer**: Interactive sunburst disk space breakdown view.
