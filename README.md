# Disk Cleaner

A native macOS disk cleanup and system utility. Single Swift binary, no runtime
dependencies, no network access.

Built after this Mac hit **249 MB free** — the first cleanup pass recovered 41 GB.

## What it does

Six pages:

| Page | What's there |
|---|---|
| **Clean** | ~30 cleanup targets grouped by risk, with per-item and per-path delete |
| **Explore** | Biggest folders, largest files, files untouched for a year |
| **Apps** | Uninstaller that finds the caches, containers and agents apps leave behind |
| **Duplicates** | Content-hash duplicate finder |
| **Maintenance** | Rebuild Launch Services, reindex Spotlight, flush DNS, reset Quick Look |
| **Activity** | Listening ports and heavy processes, with guarded quit |

Every target is labelled by risk, and the label is the contract:

- **safe** — pure cache, regenerates on its own
- **rebuild** — regenerates, but costs a re-download or a recompile first
- **review** — your own data; never selected automatically

## Safety

- `Cleaner.allowed()` is the single chokepoint every delete passes through. It
  refuses anything outside `$HOME`, and `$HOME` itself.
- Deletes go to the **Trash** by default, so a mistake is a Finder drag rather
  than data loss. Permanent delete is opt-in.
- Quitting a process refuses anything on the protected list or owned by another
  user.
- Nothing is deleted without an explicit confirmation naming the size.
- No network access at all.

## Build

```sh
./build.sh          # → out/Disk Cleaner.app  +  out/DiskCleaner-2.0.dmg
```

Signing uses the first available codesigning identity, or `SIGN_IDENTITY` if
set. This matters: macOS ties privacy grants (Documents, Downloads, Full Disk
Access) to the signing identity, and an ad-hoc signature changes hash on every
build — which silently resets every permission you granted.

Grant **Full Disk Access** once (System Settings → Privacy & Security) and the
per-folder prompts stop.

## Design notes

**Sizing is parallel.** v1 shelled out to `du -sk`, which is single-threaded.
Sizing now runs in-process via `FileManager` + `URLResourceValues`, fanned out
with `TaskGroup` — several targets in flight, and large directories split their
top-level children across cores.

**Duplicate detection is three passes, cheapest first:** bucket by exact byte
size, then a 64 KB head hash, then a full SHA-256. Most candidates die in the
first two passes, so the expensive read rarely happens.

**Liquid Glass is conditional.** `if #available(macOS 26.0, *)` applies real
glass; older systems fall back to opaque cards with the same layout. Glass needs
something behind it to refract, so the window carries a soft colour backdrop —
over a flat fill it renders as an ordinary card.

## Layout

```
Sources/
  Model.swift       types
  Catalog.swift     what the app knows how to clean
  Scanner.swift     parallel sizing, glob + dynamic path resolution
  Engine.swift      deletion, explore, composition, activity, history
  Uninstall.swift   app uninstaller, duplicates, startup items, maintenance
  AppState.swift    observable state
  Design.swift      palette, charts, glass surfaces
  CleanView.swift   the Clean page
  OtherViews.swift  Explore / Apps / Duplicates / Maintenance / Activity
legacy-hybrid/      v1: Python server + WKWebView shell, kept for reference
```

## History

**v1** was a Python HTTP server behind a WKWebView shell — 5 processes, 196 MB,
required Python. **v2** is a single native binary: 1 process, ~119 MB, no
dependencies, and gets Liquid Glass, which a web UI structurally cannot.
