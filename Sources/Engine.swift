import Foundation

// ---------------------------------------------------------------------------
// Deletion
// ---------------------------------------------------------------------------

struct CleanOutcome {
    let label: String
    let removed: Int
    let skipped: Int
    let freed: Int64
}

enum Cleaner {
    /// Nothing outside the user's home folder is ever removable, and never
    /// $HOME itself. This is the single chokepoint every delete passes through.
    static func allowed(_ path: String) -> Bool {
        let real = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        return real.hasPrefix(HOME + "/") && real != HOME
    }

    @discardableResult
    static func remove(_ path: String) -> Bool {
        guard allowed(path) else { return false }
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            return false
        }
    }

    static func clean(_ target: Target) async -> CleanOutcome {
        let before = DiskStats.current().free
        var removed = 0, skipped = 0

        switch target.source {
        case .command(let cmd, _):
            _ = Shell.bash(cmd)
            removed = 1
        case .paths, .dynamic:
            for p in Paths.expand(target) {
                if remove(p) { removed += 1 } else { skipped += 1 }
            }
        }

        for p in Paths.expand(target) { await Sizer.cache.invalidate(p) }
        await Sizer.cache.clear()

        let freed = max(0, DiskStats.current().free - before)
        return CleanOutcome(label: target.label, removed: removed, skipped: skipped, freed: freed)
    }
}

// ---------------------------------------------------------------------------
// Explore: folders, big files, forgotten files
// ---------------------------------------------------------------------------

enum Explore {
    static let hogRoots = [
        "\(HOME)/Documents", "\(HOME)/Downloads", "\(HOME)/Desktop", "\(HOME)/Movies",
        "\(HOME)/Pictures", "\(HOME)/Music", "\(HOME)/Library/Application Support",
        "\(HOME)/Library/Caches", "\(HOME)/Library/Developer", "\(HOME)/Library/Android",
        "\(HOME)/Library/Containers", "\(HOME)/Library/Group Containers",
        "\(HOME)/.gradle", "\(HOME)/.npm", "\(HOME)/.cache",
    ]

    /// Biggest folders one level inside the usual suspects.
    static func folders(limit: Int = 16, minBytes: Int64 = 500 * 1024 * 1024) async -> [FolderEntry] {
        let fm = FileManager.default
        var candidates: [(String, String)] = []
        for root in hogRoots {
            guard let kids = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for k in kids.prefix(60) where !k.hasPrefix(".") {
                candidates.append(((root as NSString).appendingPathComponent(k),
                                   (root as NSString).lastPathComponent))
            }
        }

        let sized: [FolderEntry] = await withTaskGroup(of: FolderEntry?.self) { group in
            for (path, parent) in candidates {
                group.addTask {
                    let s = await Sizer.size(path)
                    guard s >= minBytes else { return nil }
                    return FolderEntry(path: path,
                                       name: (path as NSString).lastPathComponent,
                                       parent: parent, size: s)
                }
            }
            var out: [FolderEntry] = []
            for await r in group { if let r { out.append(r) } }
            return out
        }
        return Array(sized.sorted { $0.size > $1.size }.prefix(limit))
    }

    /// Largest individual files anywhere in HOME, via Spotlight.
    static func bigFiles(limit: Int = 18, minMB: Int = 300) -> [FileEntry] {
        let q = "kMDItemFSSize > \(minMB * 1_000_000)"
        return mdfind(q).sorted { $0.size > $1.size }.prefix(limit).map { $0 }
    }

    /// Big files untouched for a year or more.
    static func staleFiles(limit: Int = 18, minMB: Int = 100, days: Int = 365) -> [FileEntry] {
        let secs = days * 86400
        let queries = [
            "kMDItemFSSize > \(minMB * 1_000_000) && kMDItemLastUsedDate < $time.now(-\(secs))",
            "kMDItemFSSize > \(minMB * 1_000_000) && kMDItemFSContentChangeDate < $time.now(-\(secs))",
        ]
        for q in queries {
            let hits = mdfind(q, wantAge: true).filter { ($0.ageDays ?? 0) >= days }
            if !hits.isEmpty {
                return Array(hits.sorted { $0.size > $1.size }.prefix(limit))
            }
        }
        return []
    }

    private static func mdfind(_ query: String, wantAge: Bool = false) -> [FileEntry] {
        guard let out = Shell.run("/usr/bin/mdfind", ["-onlyin", HOME, query]) else { return [] }
        let fm = FileManager.default
        var results: [FileEntry] = []
        for line in out.split(separator: "\n") {
            let path = String(line)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue,
                  let attrs = try? fm.attributesOfItem(atPath: path),
                  let size = (attrs[.size] as? NSNumber)?.int64Value
            else { continue }
            var age: Int? = nil
            if wantAge, let m = attrs[.modificationDate] as? Date {
                age = Int(Date().timeIntervalSince(m) / 86400)
            }
            results.append(FileEntry(path: path,
                                     name: (path as NSString).lastPathComponent,
                                     size: size,
                                     where_: tilde((path as NSString).deletingLastPathComponent),
                                     ageDays: age))
        }
        return results
    }

    static func reveal(_ path: String) {
        guard path.hasPrefix(HOME) else { return }
        Shell.run("/usr/bin/open", ["-R", path])
    }
}

// ---------------------------------------------------------------------------
// Disk composition
// ---------------------------------------------------------------------------

enum Composition {
    static let folders: [(String, String)] = [
        ("Documents", "\(HOME)/Documents"),
        ("Downloads", "\(HOME)/Downloads"),
        ("Developer", "\(HOME)/Library/Developer"),
        ("Desktop",   "\(HOME)/Desktop"),
        ("Media",     "\(HOME)/Movies"),
    ]

    static func measure() async -> [CompositionPart] {
        let disk = DiskStats.current()
        var parts: [CompositionPart] = []
        var homeTotal: Int64 = 0

        let sized = await withTaskGroup(of: (String, Int64).self) { group in
            for (name, path) in folders {
                group.addTask { (name, await Sizer.size(path)) }
            }
            group.addTask { ("Library", await Sizer.size("\(HOME)/Library")) }
            var out: [String: Int64] = [:]
            for await (n, s) in group { out[n] = s }
            return out
        }

        let developer = sized["Developer"] ?? 0
        for (name, _) in folders where (sized[name] ?? 0) > 0 {
            parts.append(CompositionPart(name: name, size: sized[name] ?? 0))
            homeTotal += sized[name] ?? 0
        }
        // Library minus Developer, which is already counted on its own.
        let restLibrary = max(0, (sized["Library"] ?? 0) - developer)
        if restLibrary > 0 {
            parts.append(CompositionPart(name: "Library", size: restLibrary))
            homeTotal += restLibrary
        }

        parts.sort { $0.size > $1.size }
        parts.append(CompositionPart(name: "System & other", size: max(0, disk.used - homeTotal)))
        parts.append(CompositionPart(name: "Free", size: disk.free))
        return parts
    }
}

// ---------------------------------------------------------------------------
// Activity: processes and listening ports
// ---------------------------------------------------------------------------

enum Activity {
    /// Quitting any of these would take the desktop down with it.
    static let protectedNames: Set<String> = [
        "kernel_task", "launchd", "WindowServer", "loginwindow", "logind", "systemstats",
        "Finder", "Dock", "SystemUIServer", "coreaudiod", "opendirectoryd", "securityd",
        "mds", "mds_stores", "mdworker", "distnoted", "cfprefsd", "UserEventAgent",
        "Disk Cleaner", "DiskCleaner",
    ]

    static func processes(limit: Int = 30) -> [ProcInfo] {
        guard let out = Shell.run("/bin/ps", ["-axo", "pid=,user=,pcpu=,rss=,comm="])
        else { return [] }
        let me = NSUserName()
        var list: [ProcInfo] = []
        for line in out.split(separator: "\n") {
            let f = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard f.count == 5, let pid = Int32(f[0]), let cpu = Double(f[2]),
                  let rssKB = Int64(f[3]) else { continue }
            let comm = String(f[4]).trimmingCharacters(in: .whitespaces)
            let name = (comm as NSString).lastPathComponent
            let user = String(f[1])
            list.append(ProcInfo(pid: pid, name: name, user: user, cpu: cpu,
                                 rss: rssKB * 1024, mine: user == me,
                                 protected: protectedNames.contains(name)))
        }
        return Array(list.sorted { $0.rss > $1.rss }.prefix(limit))
    }

    static func ports() -> [PortInfo] {
        guard let out = Shell.run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN"])
        else { return [] }
        var seen = Set<String>()
        var list: [PortInfo] = []
        for line in out.split(separator: "\n").dropFirst() {
            var f = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            // lsof appends "(LISTEN)" after the NAME column.
            while let last = f.last, last.hasPrefix("(") { f.removeLast() }
            guard f.count >= 9, let pid = Int32(f[1]), let addr = f.last,
                  let colon = addr.lastIndex(of: ":") else { continue }
            let portStr = String(addr[addr.index(after: colon)...])
            guard let port = Int(portStr) else { continue }
            let host = String(addr[..<colon])
            let key = "\(port)-\(pid)"
            if seen.contains(key) { continue }
            seen.insert(key)
            let name = f[0]
            list.append(PortInfo(port: port, pid: pid, name: name, user: f[2],
                                 addr: host.isEmpty ? "*" : host,
                                 isLocal: ["127.0.0.1", "[::1]", "localhost"].contains(host),
                                 protected: protectedNames.contains(name)))
        }
        return list.sorted { $0.port < $1.port }
    }

    enum QuitResult {
        case ok(String)
        case refused(String)
    }

    /// Terminate a process the user owns. Protected names and other users are refused.
    static func quit(pid: Int32, force: Bool = false) -> QuitResult {
        guard pid > 100 else { return .refused("Refused: system process") }
        guard let proc = processes(limit: 9999).first(where: { $0.pid == pid })
        else { return .refused("No such process") }
        guard !proc.protected else { return .refused("Refused: \(proc.name) is protected") }
        guard proc.mine else { return .refused("Refused: not your process") }

        let sig = force ? SIGKILL : SIGTERM
        if kill(pid, sig) == 0 { return .ok(proc.name) }
        return .refused(errno == EPERM ? "Permission denied" : "Could not quit")
    }
}

// ---------------------------------------------------------------------------
// Free-space history
// ---------------------------------------------------------------------------

enum History {
    static let file = "\(HOME)/.disk-cleaner-history.json"

    static func load() -> [HistorySample] {
        guard let d = FileManager.default.contents(atPath: file),
              let s = try? JSONDecoder().decode([HistorySample].self, from: d) else { return [] }
        return s
    }

    @discardableResult
    static func record() -> [HistorySample] {
        var h = load()
        let now = Date().timeIntervalSince1970
        let free = DiskStats.current().free
        if let last = h.last, now - last.t < 600 {
            h[h.count - 1] = HistorySample(t: now, free: free)
        } else {
            h.append(HistorySample(t: now, free: free))
        }
        if h.count > 180 { h = Array(h.suffix(180)) }
        if let d = try? JSONEncoder().encode(h) { try? d.write(to: URL(fileURLWithPath: file)) }
        return h
    }
}
