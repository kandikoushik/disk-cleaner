import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case clean = "Clean", explore = "Explore", apps = "Apps"
    case duplicates = "Duplicates", maintenance = "Maintenance", activity = "Activity"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .clean: return "sparkles"
        case .explore: return "chart.pie"
        case .apps: return "shippingbox"
        case .duplicates: return "doc.on.doc"
        case .maintenance: return "wrench.and.screwdriver"
        case .activity: return "bolt.horizontal"
        }
    }
}

enum SortMode: String, CaseIterable, Identifiable {
    case size = "Largest first", name = "Name", risk = "Safest first"
    var id: String { rawValue }
}

@MainActor
final class AppState: ObservableObject {

    // Navigation
    @Published var page: Page = .clean
    @Published var search = ""
    @Published var sort: SortMode = .size
    @Published var categoryFilter: Category? = nil

    // Disk
    @Published var disk = DiskStats.current()
    @Published var composition: [CompositionPart] = []
    @Published var compositionReady = false
    @Published var history: [HistorySample] = []

    // Targets
    @Published var states: [TargetState] = Catalog.targets.map { TargetState(target: $0) }
    @Published var scanning = false
    @Published var scanProgress: Double = 0
    @Published var expanded: Set<String> = []
    @Published var pathsFor: [String: [PathEntry]] = [:]

    // Explore
    @Published var folders: [FolderEntry] = []
    @Published var bigFiles: [FileEntry] = []
    @Published var staleFiles: [FileEntry] = []
    @Published var exploreLoading = false

    // Activity
    @Published var procs: [ProcInfo] = []
    @Published var ports: [PortInfo] = []
    @Published var activityStamp = ""
    @Published var autoRefresh = false
    @Published var activityLoading = false

    // Apps / uninstaller
    @Published var installedApps: [AppEntry] = []
    @Published var appsLoading = false
    @Published var selectedApp: AppEntry?

    // Duplicates
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var duplicatesLoading = false
    @Published var duplicatesScanned = false

    // Startup items
    @Published var startupItems: [LaunchAgentItem] = []

    /// Recoverable deletes are the default — every mainstream cleaner does this,
    /// and it turns a mistake into a Finder drag rather than a data loss.
    @AppStorage("useTrash") var useTrash = true

    // Feedback
    @Published var toast: String?
    private var toastTask: Task<Void, Never>?
    private var autoTask: Task<Void, Never>?

    // ---- derived ------------------------------------------------------------

    var reclaimable: Int64 { states.compactMap(\.size).reduce(0, +) }
    var selectedBytes: Int64 { states.filter(\.selected).compactMap(\.size).reduce(0, +) }
    var selectedCount: Int { states.filter(\.selected).count }
    var selectionHasReview: Bool { states.contains { $0.selected && $0.target.risk == .review } }
    var freeAfter: Int64 { disk.free + selectedBytes }

    var byCategory: [(Category, Int64)] {
        Category.allCases.compactMap { cat in
            let total = states.filter { $0.target.category == cat }.compactMap(\.size).reduce(0, +)
            return total > 0 ? (cat, total) : nil
        }
    }

    var liveCategories: [Category] {
        Category.allCases.filter { cat in
            states.contains { $0.target.category == cat && $0.hasContent }
        }
    }

    /// Rows to show, after search + category filter, grouped by risk.
    func rows(for risk: Risk) -> [TargetState] {
        var out = states.filter { $0.target.risk == risk }
            .filter { $0.size == nil || $0.hasContent }
        if let c = categoryFilter { out = out.filter { $0.target.category == c } }
        if !search.isEmpty {
            let q = search.lowercased()
            out = out.filter {
                $0.target.label.lowercased().contains(q)
                || $0.target.note.lowercased().contains(q)
                || $0.target.category.rawValue.lowercased().contains(q)
            }
        }
        switch sort {
        case .size: out.sort { ($0.size ?? 0) > ($1.size ?? 0) }
        case .name: out.sort { $0.target.label < $1.target.label }
        case .risk: out.sort { ($0.size ?? 0) > ($1.size ?? 0) }
        }
        return out
    }

    var maxRowSize: Int64 { max(states.compactMap(\.size).max() ?? 1, 1) }

    // ---- lifecycle ----------------------------------------------------------

    func start() {
        history = History.record()
        Task { await scan() }
        Task { await loadComposition() }
    }

    func refreshDisk() { disk = DiskStats.current() }

    func say(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            if !Task.isCancelled { toast = nil }
        }
    }

    // ---- scanning -----------------------------------------------------------

    func scan() async {
        guard !scanning else { return }
        scanning = true
        scanProgress = 0
        refreshDisk()
        for i in states.indices { states[i].size = nil }

        let targets = Catalog.targets
        var done = 0

        // Measure several targets at once; each also parallelises internally.
        await withTaskGroup(of: (String, Int64, Int).self) { group in
            var iterator = targets.makeIterator()
            var inFlight = 0
            let lanes = min(6, ProcessInfo.processInfo.activeProcessorCount)

            func launch() {
                guard let t = iterator.next() else { return }
                inFlight += 1
                group.addTask {
                    let paths = Paths.expand(t)
                    let size = await Sizer.sizes(paths)
                    return (t.id, size, paths.count)
                }
            }
            for _ in 0..<lanes { launch() }

            while inFlight > 0, let (id, size, count) = await group.next() {
                inFlight -= 1
                if let i = states.firstIndex(where: { $0.id == id }) {
                    states[i].size = size
                    states[i].count = count
                }
                done += 1
                scanProgress = Double(done) / Double(targets.count)
                launch()
            }
        }

        scanning = false
        refreshDisk()
        history = History.record()
        say(reclaimable > 0 ? "Found \(fmtBytes(reclaimable)) you can reclaim"
                            : "Nothing to clean — all tidy")
    }

    func loadComposition() async {
        compositionReady = false
        composition = await Composition.measure()
        compositionReady = true
    }

    func loadPaths(for state: TargetState) async {
        let paths = Paths.expand(state.target)
        let entries = await withTaskGroup(of: PathEntry.self) { group in
            for p in paths.prefix(200) {
                group.addTask { PathEntry(path: p, size: await Sizer.size(p)) }
            }
            var out: [PathEntry] = []
            for await e in group { out.append(e) }
            return out
        }
        pathsFor[state.id] = entries.sorted { $0.size > $1.size }
    }

    // ---- selection ----------------------------------------------------------

    func toggle(_ id: String) {
        guard let i = states.firstIndex(where: { $0.id == id }) else { return }
        states[i].selected.toggle()
    }
    func selectSafe() {
        for i in states.indices where states[i].target.risk == .safe && states[i].hasContent {
            states[i].selected = true
        }
        say("Selected everything safe")
    }
    func selectAllButPersonal() {
        for i in states.indices where states[i].target.risk != .review && states[i].hasContent {
            states[i].selected = true
        }
        say("Selected all except your personal data")
    }
    func clearSelection() { for i in states.indices { states[i].selected = false } }

    // ---- cleaning -----------------------------------------------------------

    func clean(ids: [String], label: String) async {
        let targets = Catalog.targets.filter { ids.contains($0.id) }
        for id in ids {
            if let i = states.firstIndex(where: { $0.id == id }) { states[i].busy = true }
        }
        var freed: Int64 = 0
        for t in targets { freed += await Cleaner.clean(t).freed }

        clearSelection()
        for i in states.indices { states[i].busy = false }
        pathsFor.removeAll()
        refreshDisk()
        say("\(label) · reclaimed \(fmtBytes(freed)) — now \(fmtBytes(disk.free)) free")
        await scan()
        await loadComposition()
    }

    func deletePath(_ entry: PathEntry, in targetID: String) async {
        guard Cleaner.remove(entry.path) else { say("Refused — outside your home folder"); return }
        await Sizer.cache.invalidate(entry.path)
        pathsFor[targetID]?.removeAll { $0.path == entry.path }
        if let i = states.firstIndex(where: { $0.id == targetID }), let s = states[i].size {
            states[i].size = max(0, s - entry.size)
        }
        refreshDisk()
        say("Deleted · reclaimed \(fmtBytes(entry.size))")
    }

    func deleteFile(_ file: FileEntry) async {
        guard Cleaner.remove(file.path) else { say("Refused — outside your home folder"); return }
        bigFiles.removeAll { $0.path == file.path }
        staleFiles.removeAll { $0.path == file.path }
        await Sizer.cache.invalidate(file.path)
        refreshDisk()
        say("Deleted · reclaimed \(fmtBytes(file.size))")
    }

    // ---- explore ------------------------------------------------------------

    func loadExplore(force: Bool = false) async {
        if !force && !folders.isEmpty { return }
        exploreLoading = true
        async let f = Explore.folders()
        let big = Explore.bigFiles()
        let stale = Explore.staleFiles()
        folders = await f
        bigFiles = big
        staleFiles = stale
        exploreLoading = false
    }

    // ---- activity -----------------------------------------------------------

    /// Reading processes and ports shells out to `top` and `lsof`. `top` needs
    /// two samples to report energy, which costs a couple of seconds — so this
    /// has to stay off the main actor or the whole window freezes while it runs.
    func loadActivity() {
        guard !activityLoading else { return }
        activityLoading = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                (procs: Activity.processes(), ports: Activity.ports())
            }.value
            procs = result.procs
            ports = result.ports
            activityStamp = "updated " + Date().formatted(date: .omitted, time: .standard)
            activityLoading = false
        }
    }

    func setAutoRefresh(_ on: Bool) {
        autoRefresh = on
        autoTask?.cancel()
        guard on else { return }
        autoTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard let self, !Task.isCancelled else { return }
                if self.page == .activity { self.loadActivity() } else { return }
            }
        }
    }

    func quit(_ proc: ProcInfo) {
        switch Activity.quit(pid: proc.pid) {
        case .ok(let name):
            say("Sent quit to \(name)")
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                loadActivity()
            }
        case .refused(let why):
            say(why)
        }
    }

    // ---- apps / uninstaller -------------------------------------------------

    func loadApps(force: Bool = false) async {
        if !force && !installedApps.isEmpty { return }
        appsLoading = true
        installedApps = await Uninstaller.scan()
        startupItems = Startup.items()
        appsLoading = false
    }

    func uninstall(_ appInfo: AppEntry) async {
        let result = Uninstaller.uninstall(appInfo, residues: appInfo.residues, permanently: !useTrash)
        selectedApp = nil
        refreshDisk()
        if result.ok {
            say("\(appInfo.name) removed · reclaimed \(fmtBytes(result.freed))")
        } else {
            say("Could not remove \(appInfo.name) — it may need admin rights")
        }
        await loadApps(force: true)
    }

    func removeStartupItem(_ item: LaunchAgentItem) {
        guard Startup.removable(item) else { say("System daemon — not removable"); return }
        if useTrash ? Trash.move(item.path) : Cleaner.remove(item.path) {
            startupItems.removeAll { $0.path == item.path }
            say("Removed \(item.label)")
        } else {
            say("Could not remove \(item.label)")
        }
    }

    // ---- duplicates ---------------------------------------------------------

    func findDuplicates() async {
        duplicatesLoading = true
        duplicateGroups = await Duplicates.find()
        duplicatesLoading = false
        duplicatesScanned = true
        let total = duplicateGroups.reduce(0) { $0 + $1.wastedSpace }
        say(total > 0 ? "Found \(fmtBytes(total)) in duplicates"
                      : "No duplicates over 5 MB")
    }

    /// Keep the first copy, remove the rest.
    func resolveDuplicate(_ group: DuplicateGroup) async {
        var freed: Int64 = 0
        for file in group.files.dropFirst() {
            let ok = useTrash ? Trash.move(file.path) : Cleaner.remove(file.path)
            if ok { freed += group.size }
        }
        duplicateGroups.removeAll { $0.hash == group.hash }
        refreshDisk()
        say("Kept 1 copy · reclaimed \(fmtBytes(freed))")
    }

    func deleteDuplicatePath(_ path: String, in group: DuplicateGroup) async {
        let ok = useTrash ? Trash.move(path) : Cleaner.remove(path)
        guard ok else { say("Could not remove that copy"); return }
        if let i = duplicateGroups.firstIndex(where: { $0.hash == group.hash }) {
            let remaining = duplicateGroups[i].files.filter { $0.path != path }
            if remaining.count > 1 {
                duplicateGroups[i] = DuplicateGroup(hash: group.hash, size: group.size,
                                                     files: remaining)
            } else {
                duplicateGroups.remove(at: i)
            }
        }
        refreshDisk()
        say("Deleted · reclaimed \(fmtBytes(group.size))")
    }

    // ---- report -------------------------------------------------------------

    func copyReport() {
        var lines = ["Disk Cleaner report", ""]
        lines.append("Free \(fmtBytes(disk.free)) of \(fmtBytes(disk.total))")
        lines.append("")
        for risk in [Risk.safe, .rebuild, .review] {
            let g = states.filter { $0.target.risk == risk && $0.hasContent }
                .sorted { ($0.size ?? 0) > ($1.size ?? 0) }
            guard !g.isEmpty else { continue }
            lines.append(risk.title.uppercased())
            for s in g {
                lines.append("  " + fmtBytes(s.size ?? 0).padding(toLength: 10, withPad: " ",
                                                                  startingAt: 0) + s.target.label)
            }
            lines.append("")
        }
        lines.append("Total reclaimable: \(fmtBytes(reclaimable))")

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(lines.joined(separator: "\n"), forType: .string)
        say("Report copied to clipboard")
    }
}
