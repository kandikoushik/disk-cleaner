# Contributing to Disk Cleaner

Thank you for your interest in contributing to **Disk Cleaner**! We welcome bug fixes, new cleanup targets, performance optimizations, multiplatform enhancements, and documentation improvements.

---

## 🚀 Getting Started

1. **Fork the Repository**: Click the **Fork** button at the top right of the [Disk Cleaner GitHub page](https://github.com/kandikoushik/disk-cleaner).
2. **Clone your Fork**:
   ```bash
   git clone https://github.com/<your-username>/disk-cleaner.git
   cd disk-cleaner
   ```
3. **Build & Run locally**:
   ```bash
   ./build.sh
   ```

---

## 🛠️ Code Architecture

- **`macOS/Sources/Catalog.swift`**: Add or modify cleanup target rules (~30 built-in rules). Every item requires an explicit risk label (`.safe`, `.rebuild`, or `.review`).
- **`macOS/Sources/Engine.swift`**: Deletion routines, explore algorithms, and activity monitoring.
- **`macOS/Sources/Uninstall.swift`**: App residue scanning & 3-pass streaming deduplication.
- **`macOS/Sources/Security.swift`**: Hardcoded `Cleaner.allowed()` safety chokepoint.

---

## 📌 Contribution Guidelines

- **Safety First**: No deletion rule should ever target paths outside `$HOME` or automatically select user files (`.review` category) by default.
- **No Dependencies**: Keep the single native binary requirement intact. Do not add external SPM dependencies unless strictly approved.
- **Commit Messages**: Follow standard conventional commits (`feat: add Xcode Simulator cache target`, `fix: handle edge case in duplicate scanner`).

---

## 📄 License

By contributing to Disk Cleaner, you agree that your contributions will be licensed under the project's [Apache License 2.0](LICENSE).
