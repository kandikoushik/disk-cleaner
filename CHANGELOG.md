# Changelog

All notable changes to **Disk Cleaner** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v3.0.0] - 2026-08-12

### 🚀 Added
- **Apache 2.0 Open Source Licensing**: Official `LICENSE` file for community development.
- **Multiplatform Ecosystem**:
  - **macOS**: Native Swift 5.10 / SwiftUI app (`DiskCleaner-3.0.dmg`).
  - **Windows**: Standalone `DiskCleaner.exe` executable and NSIS installer (`windows/build.bat`).
  - **iOS**: SwiftUI storage diagnostics companion module.
  - **Android**: Kotlin junk APK purge and storage analyzer.
- **AI & MCP Agent Support**:
  - `llms.txt` and `llms-full.txt` standard files adhering to llmstxt.org.
  - `MCP_GUIDE.md` detailing Model Context Protocol server tools (`scan_disk_space`, `list_cleanup_targets`, `find_duplicate_files`).
  - Machine-readable `--scan --json` and `--clean <target> --dry-run` CLI flags.
- **GitHub Pages Website**: Live landing page at `https://kandikoushik.github.io/disk-cleaner/`.
- **GitHub Actions CI/CD**:
  - `.github/workflows/ci.yml`: Multiplatform build verification on PRs.
  - `.github/workflows/release.yml`: Automated DMG & `.exe` packaging on version tags.
- **Community Health & Documentation**: `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `ROADMAP.md`, `MARKETING_GUIDE.md`, and `.github/ISSUE_TEMPLATE/`.

### ⚡ Changed
- Upgraded version string from `2.0` to `3.0` across all platform build runners.
- Updated root `build.sh` wrapper script.
- Replaced emoji logo with high-res native AppIcon PNG across website and open-graph social cards.

### 🗑️ Removed
- Deleted legacy Python / WKWebView v1 prototype codebase (`legacy/` directory).

---

## [v2.0.0] - 2026-08-09

### 🚀 Added
- Single native Swift 5.10 binary replacing v1 Python server shell.
- Parallel directory sizing engine utilizing Swift `TaskGroup` across CPU cores.
- 3-Pass streaming duplicate finder (Byte size → 64KB Head Hash → Full SHA-256).
- Deep App Uninstaller finding hidden Application Support, Containers, and LaunchAgents.
- System Maintenance scripts (Spotlight reindex, Launch Services rebuild, DNS flush).
- Guarded process quit shield.
- Conditional Liquid Glass UI for macOS Sonoma (14.0+).

---

## [v1.0.0] - 2026-08-01

### 🚀 Added
- Initial hybrid prototype (Python HTTP server behind WKWebView window).
