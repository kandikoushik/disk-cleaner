import SwiftUI

// ---------------------------------------------------------------------------
// Explore
// ---------------------------------------------------------------------------

struct ExploreView: View {
    @EnvironmentObject var app: AppState
    @State private var pendingDelete: FileEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { Task { await app.loadExplore(force: true) } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(app.exploreLoading)
                if app.exploreLoading {
                    ProgressView().controlSize(.small).padding(.leading, 4)
                }
                Spacer()
            }

            if !app.history.isEmpty && app.history.count > 1 {
                SectionHeader(title: "Free space over time")
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(app.history.count) samples")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        Sparkline(samples: app.history)
                    }
                }
            }

            SectionHeader(title: "Biggest folders",
                          trailing: fmtBytes(app.folders.reduce(0) { $0 + $1.size }))
            if app.folders.isEmpty {
                emptyNote(app.exploreLoading ? "Measuring…" : "No folder over 500 MB.")
            }
            ForEach(app.folders) { f in
                EntryRow(name: f.name, sub: "in \(f.parent)", size: f.size,
                         fraction: Double(f.size) / Double(max(app.folders.first?.size ?? 1, 1)),
                         badge: nil,
                         onReveal: { Explore.reveal(f.path) },
                         onDelete: nil)
            }

            SectionHeader(title: "Largest single files",
                          trailing: fmtBytes(app.bigFiles.reduce(0) { $0 + $1.size }))
            if app.bigFiles.isEmpty {
                emptyNote(app.exploreLoading ? "Searching…" : "No single file over 300 MB.")
            }
            ForEach(app.bigFiles) { f in
                EntryRow(name: f.name, sub: f.where_, size: f.size,
                         fraction: Double(f.size) / Double(max(app.bigFiles.first?.size ?? 1, 1)),
                         badge: nil,
                         onReveal: { Explore.reveal(f.path) },
                         onDelete: { pendingDelete = f })
            }

            SectionHeader(title: "Big files you haven't opened in a year",
                          trailing: fmtBytes(app.staleFiles.reduce(0) { $0 + $1.size }))
            if app.staleFiles.isEmpty {
                emptyNote(app.exploreLoading ? "Searching…"
                                             : "Nothing large has gone untouched for a year.")
            }
            ForEach(app.staleFiles) { f in
                EntryRow(name: f.name, sub: f.where_, size: f.size,
                         fraction: Double(f.size) / Double(max(app.staleFiles.first?.size ?? 1, 1)),
                         badge: f.ageDays.map { $0 >= 365 ? "\($0 / 365)y old" : "\($0)d old" },
                         onReveal: { Explore.reveal(f.path) },
                         onDelete: { pendingDelete = f })
            }
        }
        .confirmationDialog("Delete this file permanently?",
                            isPresented: .init(get: { pendingDelete != nil },
                                               set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let f = pendingDelete { Task { await app.deleteFile(f) } }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            if let f = pendingDelete {
                Text("\(tilde(f.path))\n\(fmtBytes(f.size))")
            }
        }
        .task { await app.loadExplore() }
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text).font(.system(size: 12.5)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity).padding(.vertical, 20)
    }
}

struct EntryRow: View {
    let name: String
    let sub: String
    let size: Int64
    let fraction: Double
    let badge: String?
    let onReveal: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 11) {
            MiniBar(fraction: fraction).frame(width: 64)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 13, weight: .medium))
                    .lineLimit(1).truncationMode(.middle)
                Text(sub).font(.system(size: 11)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)
            if let badge {
                Text(badge).font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.riskRebuild.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
                    .foregroundStyle(Color.riskRebuild)
            }
            Text(fmtBytes(size)).font(.system(size: 13, weight: .semibold)).monospacedDigit()
            Button("Reveal", action: onReveal).controlSize(.small)
            if let onDelete {
                Button("Delete", action: onDelete).controlSize(.small).tint(.riskReview)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 9)
        .glassSurface(radius: 11)
        .padding(.bottom, 6)
    }
}

// ---------------------------------------------------------------------------
// Activity
// ---------------------------------------------------------------------------

struct ActivityView: View {
    @EnvironmentObject var app: AppState
    @State private var pendingQuit: ProcInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button { app.loadActivity() } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(app.activityLoading)
                if app.activityLoading {
                    ProgressView().controlSize(.small)
                    Text("sampling energy…").font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Toggle("auto-refresh", isOn: Binding(
                    get: { app.autoRefresh },
                    set: { app.setAutoRefresh($0) }
                ))
                .toggleStyle(.checkbox).font(.system(size: 12))
                Spacer()
                Text(app.activityStamp).font(.system(size: 11)).foregroundStyle(.secondary)
            }

            SectionHeader(title: "Listening ports", trailing: "\(app.ports.count) listening")
            if app.ports.isEmpty {
                Text("Nothing is listening.").font(.system(size: 12.5))
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 18)
            }
            ForEach(app.ports) { p in
                HStack(spacing: 11) {
                    Text("\(p.port)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .frame(minWidth: 52)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7)
                            .fill(p.isLocal ? Color.sunk : Color.riskReview.opacity(0.13)))
                        .foregroundStyle(p.isLocal ? Color.primary : Color.riskReview)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.name).font(.system(size: 13, weight: .medium))
                        Text("pid \(p.pid) · \(p.user) · \(p.addr)")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(p.isLocal ? "local only" : "reachable")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if p.protected {
                        Text("protected").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Quit") {
                            pendingQuit = ProcInfo(pid: p.pid, name: p.name, user: p.user,
                                                   cpu: 0, rss: 0, mine: true, protected: false)
                        }
                        .controlSize(.small).tint(.riskReview)
                    }
                }
                .padding(.horizontal, 13).padding(.vertical, 9)
                .glassSurface(radius: 11)
                .padding(.bottom, 6)
            }

            SectionHeader(title: "Top processes by memory",
                          trailing: fmtBytes(app.procs.reduce(0) { $0 + $1.rss }) + " resident")
            ForEach(app.procs) { p in
                HStack(spacing: 11) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.name).font(.system(size: 13, weight: .medium))
                            .lineLimit(1).truncationMode(.middle)
                        Text("pid \(p.pid) · \(p.user)")
                            .font(.system(size: 10.5)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    stat(fmtBytes(p.rss), "memory")
                    stat(String(format: "%.1f%%", p.cpu), "cpu")
                    if p.protected {
                        Text("protected").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary).frame(width: 62)
                    } else if p.mine {
                        Button("Quit") { pendingQuit = p }
                            .controlSize(.small).tint(.riskReview).frame(width: 62)
                    } else {
                        Text("other user").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary).frame(width: 62)
                    }
                }
                .padding(.horizontal, 13).padding(.vertical, 9)
                .glassSurface(radius: 11)
                .padding(.bottom, 6)
            }
        }
        .confirmationDialog("Quit this process?",
                            isPresented: .init(get: { pendingQuit != nil },
                                               set: { if !$0 { pendingQuit = nil } }),
                            titleVisibility: .visible) {
            Button("Quit", role: .destructive) {
                if let p = pendingQuit { app.quit(p) }
                pendingQuit = nil
            }
            Button("Cancel", role: .cancel) { pendingQuit = nil }
        } message: {
            if let p = pendingQuit {
                Text("\"\(p.name)\" (pid \(p.pid))\nUnsaved work in that app will be lost.")
            }
        }
        .onAppear { app.loadActivity() }
    }

    private func stat(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value).font(.system(size: 12.5, weight: .semibold)).monospacedDigit()
            Text(caption.uppercased()).font(.system(size: 8.5, weight: .medium))
                .tracking(0.5).foregroundStyle(.secondary)
        }
        .frame(width: 66, alignment: .trailing)
    }
}

// ---------------------------------------------------------------------------
// Duplicates
// ---------------------------------------------------------------------------

struct DuplicatesView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    Task { await app.findDuplicates() }
                } label: {
                    Label(app.duplicatesLoading ? "Scanning..." : "Scan Duplicates", systemImage: "doc.on.doc")
                }
                .disabled(app.duplicatesLoading)

                if app.duplicatesLoading {
                    ProgressView().controlSize(.small).padding(.leading, 4)
                }

                Spacer()
            }

            if app.duplicateGroups.isEmpty {
                Text(app.duplicatesLoading ? "Scanning your Downloads, Documents, Desktop for duplicate files..." : "No duplicate files found.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                SectionHeader(title: "Duplicate File Groups", trailing: "\(app.duplicateGroups.count) groups")

                ForEach(app.duplicateGroups) { group in
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "doc.on.doc.fill")
                                    .foregroundStyle(Color.brand)
                                Text("Size: \(fmtBytes(group.size)) per copy")
                                    .font(.system(size: 13, weight: .bold))
                                Spacer()
                                Button("Resolve Group") {
                                    Task { await app.resolveDuplicate(group) }
                                }
                                .controlSize(.small)
                                .tint(.brand)
                            }

                            Divider()

                            ForEach(group.files) { file in
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(file.name)
                                            .font(.system(size: 12, weight: .medium))
                                        Text(file.location)
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(file.modified.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)

                                    Button {
                                        Explore.reveal(file.path)
                                    } label: {
                                        Image(systemName: "folder")
                                    }
                                    .buttonStyle(.borderless)

                                    Button {
                                        Task { await app.deleteDuplicatePath(file.path, in: group) }
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
        .task {
            if app.duplicateGroups.isEmpty && !app.duplicatesLoading {
                await app.findDuplicates()
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Apps / Uninstaller
// ---------------------------------------------------------------------------

struct AppsView: View {
    @EnvironmentObject var app: AppState
    @State private var pendingUninstall: AppEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    Task { await app.loadApps(force: true) }
                } label: {
                    Label("Refresh Apps", systemImage: "arrow.clockwise")
                }
                .disabled(app.appsLoading)

                if app.appsLoading {
                    ProgressView().controlSize(.small).padding(.leading, 4)
                }

                Spacer()
            }

            if app.appsLoading {
                ProgressView("Scanning installed applications & leftovers...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if app.installedApps.isEmpty {
                Text("No applications found.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                SectionHeader(title: "Installed Applications & Leftovers", trailing: "\(app.installedApps.count) applications")

                ForEach(app.installedApps) { item in
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Image(systemName: "shippingbox.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.brand)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 14, weight: .bold))
                                    Text(item.bundleID)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(fmtBytes(item.totalSize))
                                    .font(.system(size: 14, weight: .bold))
                                    .monospacedDigit()
                                
                                Button("Uninstall") {
                                    pendingUninstall = item
                                }
                                .glassButton()
                                .tint(.riskReview)
                            }

                            if !item.residues.isEmpty {
                                Divider()
                                Text("App Leftovers & Caches (\(item.residues.count) items):")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                ForEach(item.residues) { res in
                                    HStack {
                                        Text("• \(res.category): \(res.label)")
                                            .font(.system(size: 11))
                                        Spacer()
                                        Text(fmtBytes(res.size))
                                            .font(.system(size: 11))
                                            .monospacedDigit()
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
        .confirmationDialog("Uninstall Application?", isPresented: .init(
            get: { pendingUninstall != nil },
            set: { if !$0 { pendingUninstall = nil } }
        ), titleVisibility: .visible) {
            Button("Uninstall App & Clean Leftovers", role: .destructive) {
                if let target = pendingUninstall {
                    Task { await app.uninstall(target) }
                }
                pendingUninstall = nil
            }
            Button("Cancel", role: .cancel) { pendingUninstall = nil }
        } message: {
            if let target = pendingUninstall {
                Text("App: \(target.name)\nTotal Reclaimable: \(fmtBytes(target.totalSize)) across \(target.residues.count + 1) items.")
            }
        }
        .task {
            await app.loadApps()
        }
    }
}

// ---------------------------------------------------------------------------
// Maintenance
// ---------------------------------------------------------------------------

struct MaintenanceView: View {
    @EnvironmentObject var app: AppState
    @State private var runningTasks: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "System Maintenance & Optimization")

            ForEach(Maintenance.tasks) { task in
                Card {
                    HStack(spacing: 14) {
                        Image(systemName: task.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(Color.brand)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                                .font(.system(size: 14, weight: .semibold))
                            Text(task.note)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if runningTasks.contains(task.id) {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Run Task") {
                                runTask(task)
                            }
                            .glassButton(prominent: true)
                        }
                    }
                }
            }
        }
    }

    private func runTask(_ task: MaintenanceTask) {
        runningTasks.insert(task.id)
        Task {
            let msg = Maintenance.run(task.id)
            runningTasks.remove(task.id)
            app.say(msg)
            app.refreshDisk()
        }
    }
}

// ---------------------------------------------------------------------------
// Space Lens (Interactive Treemap Disk Map)
// ---------------------------------------------------------------------------

struct SpaceLensView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    Task { await app.loadSpaceLens() }
                } label: {
                    Label("Scan Space Lens", systemImage: "sun.max")
                }
                .disabled(app.spaceLensLoading)

                if app.spaceLensLoading {
                    ProgressView().controlSize(.small).padding(.leading, 4)
                }

                Spacer()
            }

            SectionHeader(title: "Visual Storage Map (Top Folders)")

            if app.spaceLensLoading {
                ProgressView("Building visual storage map...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if app.spaceLensNodes.isEmpty {
                Text("Tap Scan Space Lens to analyze disk folders.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                let total = max(1, app.spaceLensNodes.reduce(0) { $0 + $1.size })

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Storage Map Breakdown")
                            .font(.system(size: 13, weight: .bold))

                        StackedBar(segments: app.spaceLensNodes.enumerated().map { idx, node in
                            StackSegment(id: node.name, size: node.size, color: Color.series(idx + 1))
                        })

                        ForEach(Array(app.spaceLensNodes.enumerated()), id: \.element.id) { idx, node in
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.series(idx + 1))
                                    .frame(width: 12, height: 12)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(node.name)
                                        .font(.system(size: 13, weight: .medium))
                                    Text(tilde(node.path))
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                MiniBar(fraction: Double(node.size) / Double(total))
                                    .frame(width: 80)

                                Text(fmtBytes(node.size))
                                    .font(.system(size: 13, weight: .semibold))
                                    .monospacedDigit()

                                Button("Reveal") {
                                    Explore.reveal(node.path)
                                }
                                .controlSize(.small)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
        }
        .task {
            if app.spaceLensNodes.isEmpty && !app.spaceLensLoading {
                await app.loadSpaceLens()
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Privacy & Browser Cookie Scrubber
// ---------------------------------------------------------------------------

struct PrivacyView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    Task { await app.loadPrivacy() }
                } label: {
                    Label("Scan Privacy Data", systemImage: "lock.shield")
                }
                .disabled(app.privacyLoading)

                if app.privacyLoading {
                    ProgressView().controlSize(.small).padding(.leading, 4)
                }

                Spacer()
            }

            SectionHeader(title: "Browser History, Cookies & Cache")

            if app.privacyLoading {
                ProgressView("Scanning browser data...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if app.privacyItems.isEmpty {
                Text("No browser privacy data found.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                ForEach(app.privacyItems) { item in
                    Card {
                        HStack(spacing: 12) {
                            Image(systemName: "safari")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.brand)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.browser)
                                    .font(.system(size: 14, weight: .bold))
                                Text("\(item.category) · \(tilde(item.path))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(fmtBytes(item.size))
                                .font(.system(size: 14, weight: .bold))
                                .monospacedDigit()

                            Button("Clear Data") {
                                Task {
                                    Cleaner.remove(item.path)
                                    app.say("Cleared \(item.browser) \(item.category)")
                                    await app.loadPrivacy()
                                }
                            }
                            .glassButton()
                            .tint(.riskReview)
                        }
                    }
                }
            }
        }
        .task {
            if app.privacyItems.isEmpty && !app.privacyLoading {
                await app.loadPrivacy()
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Secure File Shredder
// ---------------------------------------------------------------------------

struct ShredderView: View {
    @EnvironmentObject var app: AppState
    @State private var shredPath: String = ""
    @State private var confirmingShred = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Secure File Shredder")

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "xmark.bin.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.riskReview)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Permanently Shred Files")
                                .font(.system(size: 14, weight: .bold))
                            Text("Overwrites target file bytes with dummy data before deletion. Irrecoverable.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    HStack(spacing: 8) {
                        TextField("Paste file path to shred (~/Downloads/secret.pdf)", text: $shredPath)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .glassSurface(radius: 8)

                        Button("Select File") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.canChooseDirectories = false
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                shredPath = url.path
                            }
                        }
                        .glassButton()
                    }

                    if !shredPath.isEmpty {
                        Button("Shred File Now") {
                            confirmingShred = true
                        }
                        .glassButton(prominent: true)
                        .tint(.riskReview)
                    }
                }
            }
        }
        .confirmationDialog("Shred File Permanently?", isPresented: $confirmingShred, titleVisibility: .visible) {
            Button("Shred Permanently", role: .destructive) {
                let target = shredPath
                shredPath = ""
                Task {
                    await app.shred(path: target)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("File: \(shredPath)\nThis action CANNOT be undone.")
        }
    }
}

// ---------------------------------------------------------------------------
// Status Menu View (Menu Bar Companion)
// ---------------------------------------------------------------------------

struct StatusMenuView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Disk Cleaner")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text("\(fmtBytes(app.disk.free)) Free")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brand)
            }

            MiniBar(fraction: app.disk.usedFraction)

            Divider()

            Button("Quick Clean Safe Caches") {
                Task {
                    let safe = app.states.filter { $0.target.risk == .safe && $0.hasContent }.map(\.id)
                    await app.clean(ids: safe, label: "Quick clean done")
                }
            }

            Button("Purge RAM Memory") {
                _ = Maintenance.run("dns")
                _ = Shell.bash("/usr/bin/purge")
                app.say("RAM purged")
            }

            Divider()

            Button("Quit Disk Cleaner") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 240)
    }
}

// ---------------------------------------------------------------------------
// Settings & Tile / Tab Customization View
// ---------------------------------------------------------------------------

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Preferences & Tab Customization")

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("General Options")
                        .font(.system(size: 14, weight: .bold))

                    Toggle("Move items to macOS Trash (recoverable delete)", isOn: $app.useTrash)
                        .toggleStyle(.switch)
                        .font(.system(size: 12.5))
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dynamic Background Theme & 3D Lighting")
                        .font(.system(size: 14, weight: .bold))

                    Picker("Select Theme Palette", selection: $app.selectedThemeRaw) {
                        ForEach(Theme.allCases) { t in
                            Text(t.rawValue).tag(t.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rearrange Tab & Tile Order")
                                .font(.system(size: 14, weight: .bold))
                            Text("Customize tab order to suit your preference. Order auto-saves instantly.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reset Default Order") {
                            app.resetPageOrder()
                        }
                        .glassButton()
                    }

                    Divider()

                    ForEach(Array(app.orderedPages.enumerated()), id: \.element.id) { idx, page in
                        HStack(spacing: 12) {
                            Image(systemName: page.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.brand)
                                .frame(width: 20)

                            Text(page.rawValue)
                                .font(.system(size: 13, weight: .semibold))

                            Spacer()

                            Button {
                                app.movePage(from: idx, up: true)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .disabled(idx == 0)
                            .buttonStyle(.plain)

                            Button {
                                app.movePage(from: idx, up: false)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .disabled(idx == app.orderedPages.count - 1)
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}


