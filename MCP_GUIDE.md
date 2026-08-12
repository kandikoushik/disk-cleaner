# Model Context Protocol (MCP) & AI Agent Integration Guide

This guide details how AI assistants (ChatGPT, Claude, Gemini, Antigravity, Cursor, Windsurf) and **MCP (Model Context Protocol)** servers can discover, inspect, and safely automate **Disk Cleaner**.

---

## 🤖 Overview for AI Agents & LLMs

Disk Cleaner is engineered with machine-readable interfaces and deterministic safety boundaries, making it ideal for AI-driven disk optimization and autonomous system maintenance.

### Key Rules for AI Execution:
1. **Always run `--dry-run` first**: Check reclaimable size before executing deletions.
2. **Observe Risk Levels**:
   - `safe`: Auto-executable in automated maintenance workflows.
   - `rebuild`: Requires explicit user confirmation before deletion.
   - `review`: NEVER auto-delete; present items to user for manual review.
3. **Safety Guarantee**: Every deletion is checked by `Cleaner.allowed()` and moves files to Trash by default.

---

## 🛠️ CLI Machine-Readable Commands

Disk Cleaner includes JSON output modes for AI agent consumption:

### 1. Scan Disk Space & Return Reclaimable Targets
```bash
# Returns all targets, risk levels, and byte counts in JSON
./out/DiskCleaner.app/Contents/MacOS/DiskCleaner --scan --json
```

### 2. Dry-Run Target Clean (Simulate Size)
```bash
# Simulates cleaning Xcode DerivedData without deleting
./out/DiskCleaner.app/Contents/MacOS/DiskCleaner --clean xcode_derived_data --dry-run
```

### 3. Execute Safe Clean
```bash
# Cleans target via Cleaner.allowed() gate
./out/DiskCleaner.app/Contents/MacOS/DiskCleaner --clean xcode_derived_data --confirm
```

### 4. Find Duplicate Files
```bash
# Scans for duplicates >= 10MB using 3-pass SHA-256 algorithm
./out/DiskCleaner.app/Contents/MacOS/DiskCleaner --duplicates --min-bytes 10485760 --json
```

---

## 🔌 Model Context Protocol (MCP) Tool Schemas

If you are configuring an MCP Server for Claude Desktop, Antigravity, or Cursor, use the following tool definition schemas:

### Tool 1: `scan_disk_space`
- **Description**: Scans the user's drive for reclaimable disk space across ~30 targets.
- **Parameters**: None.
- **Returns**: Array of target objects containing `id`, `name`, `risk`, `size_bytes`, and `paths`.

### Tool 2: `clean_target`
- **Description**: Safely cleans a specified target by moving files to Trash.
- **Parameters**:
  - `target_id` (string, required): ID of target (e.g., `xcode_derived_data`, `homebrew_cache`).
  - `dry_run` (boolean, optional): If `true`, returns calculated size without deleting. Default `true`.

### Tool 3: `find_duplicate_files`
- **Description**: Scans user directories for duplicate files using 3-pass streaming SHA-256 hash.
- **Parameters**:
  - `min_megabytes` (number, optional): Minimum file size in MB to inspect (default `10`).

---

## 📄 AI Discovery Files

- [`llms.txt`](llms.txt): Executive summary for LLM search engines.
- [`llms-full.txt`](llms-full.txt): Complete data schema and security contract.
