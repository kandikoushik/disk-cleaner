# Disk Cleaner — Open Source Project Roadmap

This roadmap outlines the planned feature additions, multiplatform expansions, and technical milestones for **Disk Cleaner**.

---

## 📍 Current Release: Version 3.0.0 (Apache 2.0 Open Source)

- ✅ Multiplatform native engines (macOS Swift, Windows C# `.exe`, iOS, Android).
- ✅ AI & Model Context Protocol (MCP) server support with `llms.txt` standard.
- ✅ High-performance GitHub Pages landing page.
- ✅ Automated GitHub Actions CI/CD pipelines.

---

## 🎯 v3.1.0 — Developer & Tooling Expansion (Q3 2026)

- [ ] **Xcode Simulator & Device Cache Wiper**: Dedicated one-click cleanup for iOS/watchOS/tvOS simulators and device support files (`~/Library/Developer/Xcode/iOS DeviceSupport`).
- [ ] **Homebrew Cask Auto-Orphan Cleaner**: Detects and purges orphaned configurations left behind by uninstalled Homebrew casks.
- [ ] **Menu Bar / System Tray Widget**: Optional lightweight menu bar status item displaying real-time disk pressure and quick-clean shortcuts.
- [ ] **Windows WinSxS Component Store Analyzer**: Detailed component store breakdown for `C:\Windows\WinSxS` with DISM integration.

---

## 🚀 v3.5.0 — Deep Analytics & Automation (Q4 2026)

- [ ] **Scheduled Auto-Cleanup Daemon**: Configurable background daemon to clean safe targets (`.safe` risk tier) on user-defined schedules (e.g. weekly).
- [ ] **Interactive Visual Tree Map**: Sunburst / Treemap visualizer for disk space breakdown (interactive DaisyDisk-style visualization).
- [ ] **Docker & Podman Volume Purger**: Detects and prunes dangling volumes, unused images, and stopped containers.

---

## 🔮 v4.0.0 — Ecosystem Convergence (2027)

- [ ] **Unified Multiplatform Sync**: Synchronize cleanup preferences and device insights across Mac, Windows, iPhone, and Android via encrypted local P2P or iCloud/OneDrive sync.
- [ ] **Plugin Target Engine**: Allow community members to contribute new cleanup target definitions using simple YAML/JSON schema plugins without recompiling the app.
