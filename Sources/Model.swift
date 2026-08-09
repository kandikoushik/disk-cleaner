import Foundation

// ---------------------------------------------------------------------------
// Core types
// ---------------------------------------------------------------------------

enum Risk: String, CaseIterable, Codable {
    case safe, rebuild, review

    var title: String {
        switch self {
        case .safe:    return "Safe to remove"
        case .rebuild: return "Costs a rebuild"
        case .review:  return "Review before you go"
        }
    }
    var blurb: String {
        switch self {
        case .safe:    return "Pure caches — these regenerate on their own"
        case .rebuild: return "Regenerates, but re-downloads or recompiles first"
        case .review:  return "Your own data — never selected automatically"
        }
    }
    var order: Int {
        switch self {
        case .safe: return 0
        case .rebuild: return 1
        case .review: return 2
        }
    }
}

enum Category: String, CaseIterable {
    case xcode = "Xcode"
    case simulators = "Simulators"
    case android = "Android"
    case packages = "Package managers"
    case apps = "Apps"
    case projects = "Projects"
    case system = "System"
    case personal = "Personal"

    /// Fixed categorical slot, assigned in order and never cycled.
    var slot: Int { (Category.allCases.firstIndex(of: self) ?? 0) + 1 }
}

/// How a target's contents are located.
enum Source {
    /// Shell-style globs; the matches themselves are removed.
    case paths([String])
    /// A shell command, with `measured` describing what to size.
    case command(String, measured: [String])
    /// Computed at runtime (project scans, NDK pruning, stale simulators).
    case dynamic(DynamicKind)
}

enum DynamicKind {
    case nodeModules, venvs, projectBuilds, oldNDKs, unavailableSimulators
}

struct Target: Identifiable {
    let id: String
    let label: String
    let note: String
    let risk: Risk
    let category: Category
    let source: Source
}

/// Live scan state for one target.
struct TargetState: Identifiable {
    let target: Target
    var size: Int64?          // nil while measuring
    var count: Int = 0
    var selected = false
    var busy = false

    var id: String { target.id }
    var measured: Bool { size != nil }
    var hasContent: Bool { (size ?? 0) > 0 }
}

struct PathEntry: Identifiable, Hashable {
    let path: String
    let size: Int64
    var id: String { path }
}

struct FileEntry: Identifiable, Hashable {
    let path: String
    let name: String
    let size: Int64
    var where_: String = ""
    var ageDays: Int? = nil
    var id: String { path }
}

struct FolderEntry: Identifiable, Hashable {
    let path: String
    let name: String
    let parent: String
    let size: Int64
    var id: String { path }
}

struct ProcInfo: Identifiable, Hashable {
    let pid: Int32
    let name: String
    let user: String
    let cpu: Double
    let rss: Int64
    let mine: Bool
    let protected: Bool
    var id: Int32 { pid }
}

struct PortInfo: Identifiable, Hashable {
    let port: Int
    let pid: Int32
    let name: String
    let user: String
    let addr: String
    let isLocal: Bool
    let protected: Bool
    var id: String { "\(port)-\(pid)" }
}

struct DiskStats: Equatable {
    var total: Int64 = 0
    var free: Int64 = 0
    var used: Int64 { total - free }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    static func current() -> DiskStats {
        let path = "/System/Volumes/Data"
        guard let a = try? FileManager.default.attributesOfFileSystem(forPath: path),
              let total = a[.systemSize] as? NSNumber,
              let free = a[.systemFreeSize] as? NSNumber
        else { return DiskStats() }
        return DiskStats(total: total.int64Value, free: free.int64Value)
    }
}

struct CompositionPart: Identifiable, Hashable {
    let name: String
    let size: Int64
    var id: String { name }
}

struct HistorySample: Identifiable, Codable, Hashable {
    let t: Double
    let free: Int64
    var id: Double { t }
}

// ---------------------------------------------------------------------------
// Duplicates, App Uninstaller, Startup & Maintenance Models
// ---------------------------------------------------------------------------

struct DuplicateFile: Identifiable, Hashable {
    let path: String
    let name: String
    let location: String
    let size: Int64
    let modified: Date
    var selected: Bool = false
    var id: String { path }
}

struct DuplicateGroup: Identifiable, Hashable {
    let hash: String
    let size: Int64
    var files: [DuplicateFile]
    var id: String { hash }
    var reclaimableSize: Int64 {
        let count = files.filter(\.selected).count
        return count > 0 ? Int64(count) * size : 0
    }
}

struct AppResidue: Identifiable, Hashable {
    let id: String
    let label: String
    let path: String
    let size: Int64
    let category: String
}

struct AppEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleID: String
    let path: String
    let appSize: Int64
    let residues: [AppResidue]
    var selected: Bool = true
    
    var residueSize: Int64 { residues.reduce(0) { $0 + $1.size } }
    var totalSize: Int64 { appSize + residueSize }
}

struct LaunchAgentItem: Identifiable, Hashable {
    let id: String
    let label: String
    let path: String
    let domain: String
    let isEnabled: Bool
    let program: String
}

struct MaintenanceTask: Identifiable {
    let id: String
    let title: String
    let note: String
    let icon: String
    var busy: Bool = false
    var lastRun: String? = nil
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

func fmtBytes(_ b: Int64) -> String {
    if b <= 0 { return "0 B" }
    let units = ["B", "KB", "MB", "GB", "TB"]
    var n = Double(b), i = 0
    while n >= 1024, i < units.count - 1 { n /= 1024; i += 1 }
    return (n < 10 && i > 1) ? String(format: "%.1f %@", n, units[i])
                             : "\(Int(n.rounded())) \(units[i])"
}

let HOME = NSHomeDirectory()

func tilde(_ p: String) -> String {
    p.hasPrefix(HOME) ? "~" + p.dropFirst(HOME.count) : p
}

