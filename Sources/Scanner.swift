import Foundation

// ---------------------------------------------------------------------------
// Sizing engine.
//
// The hybrid version shelled out to `du -sk`, which is single-threaded: one
// directory tree at a time, one core. Here the walk is done in-process with
// FileManager and fanned out across cores, which is the whole reason the native
// rewrite scans faster.
// ---------------------------------------------------------------------------

actor SizeCache {
    private var store: [String: (Date, Int64)] = [:]
    private let ttl: TimeInterval = 120

    func get(_ path: String) -> Int64? {
        guard let (when, value) = store[path], Date().timeIntervalSince(when) < ttl
        else { return nil }
        return value
    }
    func set(_ path: String, _ value: Int64) { store[path] = (Date(), value) }
    func invalidate(_ path: String) {
        for key in store.keys where key.hasPrefix(path) || path.hasPrefix(key) {
            store.removeValue(forKey: key)
        }
    }
    func clear() { store.removeAll() }
}

enum Sizer {
    static let cache = SizeCache()

    private static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey, .fileResourceIdentifierKey, .linkCountKey,
    ]

    /// Tracks inodes already counted in one scan.
    ///
    /// Hard-linked files (pnpm and npm link package contents aggressively, and
    /// Time Machine uses them everywhere) appear once per link on disk but
    /// occupy one set of blocks. Counting each link at full size inflates a
    /// folder's reported size — sometimes by a lot.
    final class SeenSet: @unchecked Sendable {
        private var seen = Set<Int>()
        private let lock = NSLock()

        /// True the first time an inode is offered, false for every repeat.
        func firstSight(_ id: Int) -> Bool {
            lock.lock(); defer { lock.unlock() }
            return seen.insert(id).inserted
        }
    }

    /// Bytes actually occupied on disk by a single file.
    ///
    /// When `seen` is supplied, a file with multiple hard links is counted only
    /// the first time it is encountered in that scan.
    private static func allocated(_ url: URL, seen: SeenSet? = nil) -> Int64 {
        guard let v = try? url.resourceValues(forKeys: keys) else { return 0 }
        if let seen, let links = v.linkCount, links > 1 {
            var inode = 0
            if let idAny = v.fileResourceIdentifier {
                // fileResourceIdentifier is opaque but stable and hashable per file.
                inode = (idAny as AnyObject).hash
            }
            if inode != 0, !seen.firstSight(inode) { return 0 }
        }
        if let a = v.totalFileAllocatedSize { return Int64(a) }
        if let a = v.fileAllocatedSize { return Int64(a) }
        return 0
    }

    /// Walk one subtree on the current thread. Symlinks are counted as entries,
    /// never followed — otherwise a loop would hang the scan.
    static func walk(_ path: String, seen: SeenSet? = nil) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }
        let url = URL(fileURLWithPath: path)

        if !isDir.boolValue { return allocated(url, seen: seen) }
        if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
            return 0
        }

        var total: Int64 = 0
        guard let e = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys),
                                    options: [.skipsHiddenFiles.subtracting(.skipsHiddenFiles)],
                                    errorHandler: { _, _ in true })
        else { return 0 }
        for case let child as URL in e {
            let v = try? child.resourceValues(forKeys: keys)
            if v?.isSymbolicLink == true { e.skipDescendants(); continue }
            if v?.isDirectory == true { continue }
            total += allocated(child, seen: seen)
        }
        return total
    }

    /// Size a path, splitting large directories across cores.
    static func size(_ path: String, useCache: Bool = true) async -> Int64 {
        if useCache, let hit = await cache.get(path) { return hit }
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
            await cache.invalidate(path)
            return 0
        }

        // One shared inode set per top-level measurement, so hard links are
        // counted once even when the walk is split across cores.
        let seen = SeenSet()
        var total: Int64 = 0
        if isDir.boolValue,
           let children = try? fm.contentsOfDirectory(atPath: path), children.count > 1 {
            // Fan the top-level children out; this is where the parallelism pays.
            total = await withTaskGroup(of: Int64.self) { group in
                for c in children {
                    let sub = (path as NSString).appendingPathComponent(c)
                    group.addTask { walk(sub, seen: seen) }
                }
                var sum: Int64 = 0
                for await v in group { sum += v }
                return sum
            }
        } else {
            total = walk(path, seen: seen)
        }

        await cache.set(path, total)
        return total
    }

    static func sizes(_ paths: [String]) async -> Int64 {
        await withTaskGroup(of: Int64.self) { group in
            for p in paths { group.addTask { await size(p) } }
            var sum: Int64 = 0
            for await v in group { sum += v }
            return sum
        }
    }
}

// ---------------------------------------------------------------------------
// Path resolution
// ---------------------------------------------------------------------------

enum Paths {
    /// Shell-style glob expansion via the C library.
    static func glob(_ pattern: String) -> [String] {
        var g = glob_t()
        defer { globfree(&g) }
        guard Darwin.glob(pattern, GLOB_TILDE | GLOB_BRACE, nil, &g) == 0 else { return [] }
        var out: [String] = []
        for i in 0..<Int(g.gl_pathc) {
            if let p = g.gl_pathv[i] { out.append(String(cString: p)) }
        }
        return out
    }

    static let github = "\(HOME)/Documents/Github"

    /// Depth-limited search for directories with any of the given names.
    /// Matches are not descended into.
    static func findDirs(named names: Set<String>, under root: String, maxDepth: Int) -> [String] {
        let fm = FileManager.default
        var found: [String] = []
        var frontier = [(root, 0)]
        while let (dir, depth) = frontier.popLast() {
            guard depth < maxDepth,
                  let kids = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for k in kids {
                let full = (dir as NSString).appendingPathComponent(k)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue
                else { continue }
                if names.contains(k) {
                    found.append(full)          // don't descend into a match
                } else {
                    frontier.append((full, depth + 1))
                }
            }
        }
        return found
    }

    /// NDK versions safe to delete: everything except the newest and any version
    /// pinned by a build.gradle.
    static func removableNDKs() -> [String] {
        let root = "\(HOME)/Library/Android/sdk/ndk"
        guard let versions = try? FileManager.default.contentsOfDirectory(atPath: root),
              versions.count > 1 else { return [] }
        let sorted = versions.sorted()
        var keep = Set<String>()
        if let newest = sorted.last { keep.insert(newest) }
        keep.formUnion(pinnedNDKVersions())
        return sorted.filter { !keep.contains($0) }
                     .map { (root as NSString).appendingPathComponent($0) }
    }

    private static func pinnedNDKVersions() -> Set<String> {
        var pinned = Set<String>()
        let fm = FileManager.default
        guard let e = fm.enumerator(atPath: github) else { return pinned }
        var checked = 0
        for case let rel as String in e {
            guard checked < 4000 else { break }
            checked += 1
            guard rel.hasSuffix(".gradle") || rel.hasSuffix(".kts") || rel.hasSuffix(".properties")
            else { continue }
            if rel.contains("node_modules") { e.skipDescendants(); continue }
            let full = (github as NSString).appendingPathComponent(rel)
            guard let text = try? String(contentsOfFile: full, encoding: .utf8),
                  text.contains("ndkVersion") else { continue }
            for line in text.split(separator: "\n") where line.contains("ndkVersion") {
                for token in line.split(whereSeparator: { "\"' \t=".contains($0) }) {
                    if let f = token.first, f.isNumber, token.contains(".") {
                        pinned.insert(String(token))
                    }
                }
            }
        }
        return pinned
    }

    /// Simulator device folders whose runtime is gone.
    static func unavailableSimulators() -> [String] {
        let root = "\(HOME)/Library/Developer/CoreSimulator/Devices"
        guard FileManager.default.fileExists(atPath: root) else { return [] }
        guard let out = Shell.run("/usr/bin/xcrun", ["simctl", "list", "devices", "-j"]),
              let data = out.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [String: [[String: Any]]]
        else { return [] }

        var dirs: [String] = []
        for (runtime, list) in devices {
            let staleRuntime = runtime.lowercased().contains("unavailable")
            for d in list {
                let available = d["isAvailable"] as? Bool ?? true
                guard staleRuntime || !available, let udid = d["udid"] as? String else { continue }
                let p = (root as NSString).appendingPathComponent(udid)
                if FileManager.default.fileExists(atPath: p) { dirs.append(p) }
            }
        }
        return dirs
    }

    static let buildNames: Set<String> = ["build", ".next", "dist", "__pycache__", "DerivedData"]
    static let venvNames: Set<String> = ["venv", ".venv"]

    /// Every concrete path a target would delete.
    static func expand(_ target: Target) -> [String] {
        switch target.source {
        case .paths(let patterns):
            return patterns.flatMap { glob($0) }
        case .command(_, let measured):
            return measured.flatMap { glob($0) }
        case .dynamic(let kind):
            switch kind {
            case .nodeModules:
                return findDirs(named: ["node_modules"], under: github, maxDepth: 4)
            case .venvs:
                return findDirs(named: venvNames, under: github, maxDepth: 4)
                    .filter { !$0.contains("node_modules") }
            case .projectBuilds:
                return findDirs(named: buildNames, under: github, maxDepth: 5)
                    .filter { !$0.contains("node_modules") }
            case .oldNDKs:
                return removableNDKs()
            case .unavailableSimulators:
                return unavailableSimulators()
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Subprocess helper
// ---------------------------------------------------------------------------

enum Shell {
    @discardableResult
    static func run(_ launch: String, _ args: [String], timeout: TimeInterval = 120) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launch)
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        p.environment = env
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }

        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }

    static func bash(_ command: String) -> String? {
        run("/bin/bash", ["-lc", command])
    }
}
