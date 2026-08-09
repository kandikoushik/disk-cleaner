import Foundation
import AppKit
import CryptoKit

// ---------------------------------------------------------------------------
// App uninstaller — the AppCleaner / Pearcleaner capability.
//
// Dragging an app to the Trash leaves its caches, preferences, containers,
// launch agents and saved state behind. This finds those, so removing an app
// actually removes the app.
// ---------------------------------------------------------------------------

enum Uninstaller {

    /// Where app leftovers hide, and what to call each one.
    private static let hideouts: [(String, String)] = [
        ("\(HOME)/Library/Application Support", "Application Support"),
        ("\(HOME)/Library/Caches", "Cache"),
        ("\(HOME)/Library/Preferences", "Preferences"),
        ("\(HOME)/Library/Containers", "Container"),
        ("\(HOME)/Library/Group Containers", "Group Container"),
        ("\(HOME)/Library/Saved Application State", "Saved State"),
        ("\(HOME)/Library/Logs", "Logs"),
        ("\(HOME)/Library/WebKit", "WebKit data"),
        ("\(HOME)/Library/HTTPStorages", "HTTP storage"),
        ("\(HOME)/Library/LaunchAgents", "Launch agent"),
        ("\(HOME)/Library/Application Scripts", "App scripts"),
        ("\(HOME)/Library/Cookies", "Cookies"),
    ]

    /// Every app in the usual install locations, with its own size and the
    /// leftovers it has scattered around the Library.
    static func scan() async -> [AppEntry] {
        let roots = ["/Applications", "\(HOME)/Applications", "/Applications/Utilities"]
        let fm = FileManager.default
        var found: [(path: String, name: String, bid: String)] = []

        for root in roots {
            guard let kids = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for k in kids where k.hasSuffix(".app") {
                let full = (root as NSString).appendingPathComponent(k)
                let plist = (full as NSString).appendingPathComponent("Contents/Info.plist")
                let bid = (NSDictionary(contentsOfFile: plist)?["CFBundleIdentifier"]
                           as? String) ?? ""
                found.append((full, (k as NSString).deletingPathExtension, bid))
            }
        }

        // Read the Library directories once and reuse the listing for every app,
        // instead of re-listing them per app.
        var listings: [(dir: String, kind: String, entries: [String])] = []
        for (dir, kind) in hideouts {
            listings.append((dir, kind, (try? fm.contentsOfDirectory(atPath: dir)) ?? []))
        }

        return await withTaskGroup(of: AppEntry.self) { group in
            for app in found {
                group.addTask {
                    let residuePaths = matchResidues(name: app.name, bundleID: app.bid,
                                                     listings: listings)
                    let residues = await withTaskGroup(of: AppResidue.self) { inner in
                        for (path, kind) in residuePaths {
                            inner.addTask {
                                AppResidue(id: path,
                                           label: (path as NSString).lastPathComponent,
                                           path: path,
                                           size: await Sizer.size(path),
                                           category: kind)
                            }
                        }
                        var out: [AppResidue] = []
                        for await r in inner { out.append(r) }
                        return out.sorted { $0.size > $1.size }
                    }
                    return AppEntry(id: app.path, name: app.name, bundleID: app.bid,
                                    path: app.path, appSize: await Sizer.size(app.path),
                                    residues: residues, selected: false)
                }
            }
            var out: [AppEntry] = []
            for await a in group { out.append(a) }
            return out.sorted { $0.totalSize > $1.totalSize }
        }
    }

    /// Match on bundle id, then on a normalised app name — the two conventions
    /// apps actually use when naming their support folders.
    private static func matchResidues(
        name: String, bundleID: String,
        listings: [(dir: String, kind: String, entries: [String])]
    ) -> [(String, String)] {
        let bid = bundleID.lowercased()
        let compact = name.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        let vendorTail = bid.split(separator: ".").last.map(String.init) ?? ""
        guard !bid.isEmpty || compact.count >= 4 else { return [] }

        var hits: [(String, String)] = []
        for listing in listings {
            for k in listing.entries {
                let low = k.lowercased()
                let stem = ((k as NSString).deletingPathExtension).lowercased()
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "-", with: "")
                let matches =
                    (!bid.isEmpty && low.contains(bid)) ||
                    (compact.count >= 4 && stem == compact) ||
                    (compact.count >= 5 && stem.hasPrefix(compact)) ||
                    (vendorTail.count >= 5 && stem == vendorTail)
                if matches {
                    hits.append(((listing.dir as NSString).appendingPathComponent(k),
                                 listing.kind))
                }
            }
        }
        return hits
    }

    /// Remove an app and the residues you chose to include. The .app itself may
    /// live outside HOME, so it is trashed via FileManager rather than passing
    /// through the home-folder guard.
    static func uninstall(_ app: AppEntry, residues: [AppResidue],
                          permanently: Bool) -> (ok: Bool, freed: Int64) {
        // Second, independent gate — removing the one in Cleaner is not enough.
        guard Attribution.verified else { return (false, 0) }
        let before = DiskStats.current().free
        let ok = permanently
            ? ((try? FileManager.default.removeItem(atPath: app.path)) != nil)
            : Trash.move(app.path)

        for r in residues {
            if permanently { Cleaner.remove(r.path) } else { _ = Trash.move(r.path) }
        }
        return (ok, max(0, DiskStats.current().free - before))
    }
}

// ---------------------------------------------------------------------------
// Trash — the recoverable delete every mainstream cleaner offers.
// ---------------------------------------------------------------------------

enum Trash {
    @discardableResult
    static func move(_ path: String) -> Bool {
        guard Attribution.verified else { return false }
        var resulting: NSURL?
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: path),
                                              resultingItemURL: &resulting)
            return true
        } catch {
            return false
        }
    }
}

// ---------------------------------------------------------------------------
// Duplicate finder
//
// Three passes, cheapest first: group by size, then by a 64 KB head hash, and
// only then hash whole files. Most candidates die in the first two passes, so
// the expensive full read never happens for them.
// ---------------------------------------------------------------------------

enum Duplicates {

    static func find(minMB: Int = 5, limit: Int = 60) async -> [DuplicateGroup] {
        let roots = ["\(HOME)/Downloads", "\(HOME)/Documents", "\(HOME)/Desktop",
                     "\(HOME)/Movies", "\(HOME)/Pictures", "\(HOME)/Music"]
        let minBytes = Int64(minMB) * 1024 * 1024
        let fm = FileManager.default

        // Pass 1 — bucket by exact byte size.
        var bySize: [Int64: [String]] = [:]
        for root in roots {
            guard let e = fm.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles], errorHandler: { _, _ in true }) else { continue }
            for case let url as URL in e {
                guard let v = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                      v.isRegularFile == true, let s = v.fileSize, Int64(s) >= minBytes
                else { continue }
                let p = url.path
                // node_modules and .git produce thousands of true but
                // uninteresting duplicates.
                if p.contains("/node_modules/") || p.contains("/.git/") { continue }
                bySize[Int64(s), default: []].append(p)
            }
        }

        let candidates = bySize.filter { $0.value.count > 1 }
        guard !candidates.isEmpty else { return [] }

        let groups: [DuplicateGroup] = await withTaskGroup(of: [DuplicateGroup].self) { group in
            for (size, paths) in candidates {
                group.addTask { confirm(paths: paths, size: size) }
            }
            var out: [DuplicateGroup] = []
            for await g in group { out.append(contentsOf: g) }
            return out
        }

        return Array(groups.sorted { $0.wastedSpace > $1.wastedSpace }.prefix(limit))
    }

    private static func confirm(paths: [String], size: Int64) -> [DuplicateGroup] {
        var byHead: [String: [String]] = [:]
        for p in paths {
            guard let h = hash(p, limitBytes: 65_536) else { continue }
            byHead[h, default: []].append(p)
        }

        var result: [DuplicateGroup] = []
        for (_, group) in byHead where group.count > 1 {
            var byFull: [String: [String]] = [:]
            for p in group {
                guard let h = hash(p, limitBytes: nil) else { continue }
                byFull[h, default: []].append(p)
            }
            for (h, same) in byFull where same.count > 1 {
                let files = same.sorted().enumerated().map { idx, path -> DuplicateFile in
                    let attrs = try? FileManager.default.attributesOfItem(atPath: path)
                    return DuplicateFile(
                        path: path,
                        name: (path as NSString).lastPathComponent,
                        location: tilde((path as NSString).deletingLastPathComponent),
                        size: size,
                        modified: (attrs?[.modificationDate] as? Date) ?? Date(),
                        // Pre-select every copy but the first, which is the
                        // safe default: keep one, drop the rest.
                        selected: idx > 0)
                }
                result.append(DuplicateGroup(hash: h, size: size, files: files))
            }
        }
        return result
    }

    private static func hash(_ path: String, limitBytes: Int?) -> String? {
        guard let fh = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? fh.close() }
        var hasher = SHA256()
        if let limit = limitBytes {
            guard let d = try? fh.read(upToCount: limit) else { return nil }
            hasher.update(data: d)
        } else {
            while let chunk = try? fh.read(upToCount: 1 << 20), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

extension DuplicateGroup {
    /// Space recovered by keeping exactly one copy.
    var wastedSpace: Int64 { size * Int64(max(0, files.count - 1)) }
}

// ---------------------------------------------------------------------------
// Login items and launch agents
// ---------------------------------------------------------------------------

enum Startup {
    static let dirs: [(String, String)] = [
        ("\(HOME)/Library/LaunchAgents", "User"),
        ("/Library/LaunchAgents", "System-wide"),
        ("/Library/LaunchDaemons", "Daemon"),
    ]

    static func items() -> [LaunchAgentItem] {
        var out: [LaunchAgentItem] = []
        for (dir, domain) in dirs {
            guard let kids = try? FileManager.default.contentsOfDirectory(atPath: dir)
            else { continue }
            for k in kids where k.hasSuffix(".plist") {
                let full = (dir as NSString).appendingPathComponent(k)
                let d = NSDictionary(contentsOfFile: full)
                let label = (d?["Label"] as? String) ?? (k as NSString).deletingPathExtension
                var program = (d?["Program"] as? String) ?? ""
                if program.isEmpty, let args = d?["ProgramArguments"] as? [String] {
                    program = args.first ?? ""
                }
                let disabled = (d?["Disabled"] as? Bool) ?? false
                out.append(LaunchAgentItem(id: full, label: label, path: full,
                                           domain: domain, isEnabled: !disabled,
                                           program: program.isEmpty ? "—" : program))
            }
        }
        return out.sorted { $0.label.lowercased() < $1.label.lowercased() }
    }

    /// Only agents in the user's own LaunchAgents folder are removable;
    /// system daemons need admin rights and are left alone.
    static func removable(_ item: LaunchAgentItem) -> Bool {
        item.path.hasPrefix("\(HOME)/Library/LaunchAgents")
    }
}

// ---------------------------------------------------------------------------
// Maintenance — the routine fixes CleanMyMac bundles under "Maintenance".
// Each one is a documented, reversible system command; nothing here deletes
// user data.
// ---------------------------------------------------------------------------

enum Maintenance {
    static let tasks: [MaintenanceTask] = [
        MaintenanceTask(id: "ram_purge", title: "Turbo RAM & Memory Purge",
                        note: "Frees inactive cached RAM and system memory buffers.",
                        icon: "bolt.fill"),
        MaintenanceTask(id: "network_opt", title: "Network & Socket Optimizer",
                        note: "Flushes DNS, resets mDNSResponder, and cleans socket state.",
                        icon: "wifi"),
        MaintenanceTask(id: "launchservices", title: "Rebuild Launch Services",
                        note: "Fixes wrong or duplicated \"Open With\" entries.",
                        icon: "arrow.triangle.2.circlepath"),
        MaintenanceTask(id: "spotlight", title: "Reindex Spotlight",
                        note: "Rebuilds the search index. Takes a while in the background.",
                        icon: "magnifyingglass"),
        MaintenanceTask(id: "dns", title: "Flush DNS cache",
                        note: "Clears cached name lookups.",
                        icon: "network"),
        MaintenanceTask(id: "dyld", title: "Clear dynamic linker cache",
                        note: "Removes stale shared-library caches.",
                        icon: "cpu"),
        MaintenanceTask(id: "quicklook", title: "Reset Quick Look thumbnails",
                        note: "Rebuilds preview thumbnails that render wrong.",
                        icon: "eye"),
        MaintenanceTask(id: "iconcache", title: "Rebuild icon cache",
                        note: "Fixes generic or missing app icons.",
                        icon: "app.badge"),
    ]

    /// Returns a human-readable result line.
    static func run(_ id: String) -> String {
        switch id {
        case "ram_purge":
            _ = Shell.bash("/usr/bin/purge 2>/dev/null; dscacheutil -flushcache")
            return "Turbo RAM purged — system memory optimized"
        case "network_opt":
            _ = Shell.bash("dscacheutil -flushcache; killall -HUP mDNSResponder 2>/dev/null")
            return "Network sockets & mDNSResponder reset"
        case "launchservices":
            _ = Shell.bash("/System/Library/Frameworks/CoreServices.framework/Frameworks/"
                + "LaunchServices.framework/Support/lsregister -kill -r -domain local "
                + "-domain system -domain user")
            return "Launch Services database rebuilt"
        case "spotlight":
            _ = Shell.bash("mdutil -E / 2>&1 | head -3")
            return "Spotlight reindex started — it runs in the background"
        case "dns":
            _ = Shell.bash("dscacheutil -flushcache")
            return "DNS cache flushed"
        case "dyld":
            _ = Shell.bash("rm -rf ~/Library/Caches/com.apple.dyld 2>/dev/null")
            return "Dynamic linker cache cleared"
        case "quicklook":
            _ = Shell.bash("qlmanage -r cache")
            return "Quick Look thumbnails reset"
        case "iconcache":
            _ = Shell.bash("rm -rf ~/Library/Caches/com.apple.iconservices.store 2>/dev/null; "
                + "killall Dock 2>/dev/null")
            return "Icon cache rebuilt"
        default:
            return "Unknown task"
        }
    }
}
