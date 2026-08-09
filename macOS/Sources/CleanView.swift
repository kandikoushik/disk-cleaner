import SwiftUI

struct CleanView: View {
    @EnvironmentObject var app: AppState
    @State private var confirming: ConfirmKind?

    enum ConfirmKind: Identifiable {
        case selection, quick, single(TargetState)
        var id: String {
            switch self {
            case .selection: return "sel"
            case .quick: return "quick"
            case .single(let s): return "one-\(s.id)"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            charts
            toolbar
            chips
            targetList
        }
        .confirmationDialog(confirmTitle, isPresented: .init(
            get: { confirming != nil },
            set: { if !$0 { confirming = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) { runConfirmed() }
            Button("Cancel", role: .cancel) { confirming = nil }
        } message: {
            Text(confirmMessage)
        }
    }

    // ---- charts -------------------------------------------------------------

    private var charts: some View {
        // Side by side when there is room; stacked once the window narrows.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 10) { chartCards }
            VStack(alignment: .leading, spacing: 10) { chartCards }
        }
    }

    @ViewBuilder
    private var chartCards: some View {
        Group {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Reclaimable by category")
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(app.byCategory.isEmpty
                         ? "Nothing reclaimable"
                         : "\(fmtBytes(app.reclaimable)) across \(app.byCategory.count) categories")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    StackedBar(segments: app.byCategory
                        .sorted { $0.1 > $1.1 }
                        .map { StackSegment(id: $0.0.rawValue, size: $0.1,
                                            color: .series($0.0.slot)) })
                    LegendRow(items: app.byCategory.sorted { $0.1 > $1.1 }
                        .map { (name: $0.0.rawValue, size: $0.1, color: Color.series($0.0.slot)) }) { name in
                            app.categoryFilter = Category(rawValue: name)
                        }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What is filling your disk")
                        .font(.system(size: 12.5, weight: .semibold))
                    HStack(spacing: 6) {
                        if !app.compositionReady { ProgressView().controlSize(.small) }
                        Text(app.compositionReady
                             ? "\(fmtBytes(app.disk.used)) used of \(fmtBytes(app.disk.total))"
                             : "measuring your folders…")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    StackedBar(segments: compositionSegments)
                    LegendRow(items: app.composition.filter { $0.size > 0 }.map {
                        (name: $0.name, size: $0.size, color: compositionColor($0.name))
                    })
                }
            }
        }
    }

    private var compositionSegments: [StackSegment] {
        app.composition.filter { $0.size > 0 }
            .map { StackSegment(id: $0.name, size: $0.size, color: compositionColor($0.name)) }
    }

    /// "Free" takes the neutral track colour and "System & other" a grey — only
    /// the user's own folders get categorical hues.
    private func compositionColor(_ name: String) -> Color {
        if name == "Free" { return .neutralFill }
        if name == "System & other" { return .secondary.opacity(0.55) }
        let ordered = app.composition.filter { $0.name != "Free" && $0.name != "System & other" }
        let idx = (ordered.firstIndex { $0.name == name } ?? 0) + 1
        return .series(idx)
    }

    // ---- toolbar ------------------------------------------------------------

    private var toolbar: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                // Top Row: Search, Sorting & Actions
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.brand)
                            .font(.system(size: 12, weight: .bold))
                        TextField("Search targets…", text: $app.search)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .glassSurface(radius: 8)
                    .frame(maxWidth: 240)

                    Picker("Sort", selection: $app.sort) {
                        ForEach(SortMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 140)

                    Spacer()

                    Button { Task { await app.scan(); await app.loadComposition() } } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .glassButton()
                    .disabled(app.scanning)

                    Button { confirming = .quick } label: {
                        Label("Quick Clean", systemImage: "bolt.fill")
                    }
                    .glassButton()
                    .disabled(app.scanning || !app.states.contains { $0.target.risk == .safe && $0.hasContent })

                    Button("Copy Report") { app.copyReport() }
                        .glassButton()
                }

                Divider()

                // Bottom Row: Selection Pill (Safe | All | Clear) & Elevated Clean CTA Button
                HStack(spacing: 12) {
                    HStack(spacing: 0) {
                        Button("Safe") { app.selectSafe() }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.riskSafe)

                        Divider().frame(height: 14)

                        Button("All") { app.selectAllButPersonal() }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .font(.system(size: 12, weight: .semibold))

                        Divider().frame(height: 14)

                        Button("Clear") { app.clearSelection() }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .background(Color.sunk, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.hairline))

                    Spacer()

                    Button {
                        confirming = .selection
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                            Text(app.selectedCount > 0
                                 ? "Clean \(app.selectedCount) · \(fmtBytes(app.selectedBytes))"
                                 : "Clean Selected")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .padding(.horizontal, 18).padding(.vertical, 7)
                        .background(
                            app.selectedCount > 0
                                ? LinearGradient(colors: [.brand, .brand2], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.secondary.opacity(0.18), Color.secondary.opacity(0.12)], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .foregroundStyle(app.selectedCount > 0 ? Color.white : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(app.selectedCount == 0 || app.scanning)
                }
            }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                chip(label: "Everything",
                     dot: nil,
                     amount: app.reclaimable,
                     active: app.categoryFilter == nil) { app.categoryFilter = nil }

                ForEach(app.liveCategories, id: \.self) { cat in
                    chip(label: cat.rawValue,
                         dot: .series(cat.slot),
                         amount: app.byCategory.first { $0.0 == cat }?.1 ?? 0,
                         active: app.categoryFilter == cat) {
                        app.categoryFilter = (app.categoryFilter == cat) ? nil : cat
                    }
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 2)
        }
        .padding(.bottom, 6)
    }

    /// A filter chip carries the category's colour from the chart above and the
    /// amount it accounts for, so the row reads as a legend you can click rather
    /// than a row of identical white pills.
    private func chip(label: String, dot: Color?, amount: Int64,
                      active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dot {
                    Circle().fill(dot).frame(width: 7, height: 7)
                } else {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(active ? Color.brand : .secondary)
                }
                Text(label)
                    .font(.system(size: 12, weight: active ? .semibold : .medium))
                if amount > 0 {
                    Text(fmtBytes(amount))
                        .font(.system(size: 10.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5).padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.primary.opacity(0.07)))
                }
            }
            .padding(.leading, 11).padding(.trailing, amount > 0 ? 7 : 11)
            .padding(.vertical, 6)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? Color.primary : .secondary)
        .background {
            Capsule().fill(active ? Color.brand.opacity(0.16) : Color.primary.opacity(0.035))
        }
        .overlay {
            Capsule().strokeBorder(active ? Color.brand.opacity(0.55)
                                          : Color.primary.opacity(0.09),
                                   lineWidth: active ? 1.2 : 1)
        }
        .animation(.easeOut(duration: 0.14), value: active)
    }

    // ---- list ---------------------------------------------------------------

    private var targetList: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if app.scanning {
                ProgressView(value: app.scanProgress)
                    .progressViewStyle(.linear).tint(.brand)
                    .padding(.vertical, 4)
            }
            ForEach([Risk.safe, .rebuild, .review], id: \.self) { risk in
                let rows = app.rows(for: risk)
                if !rows.isEmpty {
                    SectionHeader(title: risk.title,
                                  trailing: fmtBytes(rows.compactMap(\.size).reduce(0, +)))
                        .help(risk.blurb)
                    ForEach(rows) { state in
                        TargetRow(state: state, maxSize: app.maxRowSize) {
                            confirming = .single(state)
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            if app.rows(for: .safe).isEmpty && app.rows(for: .rebuild).isEmpty
                && app.rows(for: .review).isEmpty && !app.scanning {
                Text(app.search.isEmpty ? "✨ Nothing to clean — all clear."
                                        : "No target matches that search.")
                    .font(.system(size: 12.5)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
            }
        }
    }

    // ---- confirmation -------------------------------------------------------

    private var confirmTitle: String {
        switch confirming {
        case .quick: return "Quick clean every safe cache?"
        case .single(let s): return "Clean \"\(s.target.label)\"?"
        case .selection, .none: return "Delete selected items?"
        }
    }

    private var confirmMessage: String {
        switch confirming {
        case .quick:
            let safe = app.states.filter { $0.target.risk == .safe && $0.hasContent }
            return "\(safe.count) items · about \(fmtBytes(safe.compactMap(\.size).reduce(0, +)))."
                 + "\nThese all regenerate on their own."
        case .single(let s):
            return "About \(fmtBytes(s.size ?? 0)) will be permanently deleted."
        case .selection:
            let risky = app.states.filter { $0.selected && $0.target.risk != .safe }
            var m = "\(app.selectedCount) item(s) — about \(fmtBytes(app.selectedBytes))."
            if !risky.isEmpty {
                m += "\n\nNot pure cache:\n" + risky.map { "· " + $0.target.label }
                    .joined(separator: "\n")
            }
            return m
        case .none: return ""
        }
    }

    private func runConfirmed() {
        let kind = confirming
        confirming = nil
        Task {
            switch kind {
            case .quick:
                let ids = app.states.filter { $0.target.risk == .safe && $0.hasContent }.map(\.id)
                await app.clean(ids: ids, label: "Quick clean done")
            case .single(let s):
                await app.clean(ids: [s.id], label: "\(s.target.label) cleaned")
            case .selection:
                await app.clean(ids: app.states.filter(\.selected).map(\.id), label: "Cleaned")
            case .none: break
            }
        }
    }
}

// ---------------------------------------------------------------------------

struct TargetRow: View {
    @EnvironmentObject var app: AppState
    let state: TargetState
    let maxSize: Int64
    let onCleanOne: () -> Void

    private var isOpen: Bool { app.expanded.contains(state.id) }
    @State private var picked: Set<String> = []

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle().fill(state.target.risk.color).frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            Toggle("", isOn: Binding(
                get: { state.selected },
                set: { _ in app.toggle(state.id) }
            ))
            .labelsHidden().toggleStyle(.checkbox).padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(state.target.label).font(.system(size: 13.5, weight: .medium))
                    RiskTag(risk: state.target.risk)
                    Spacer()
                    if let s = state.size {
                        Text(fmtBytes(s)).font(.system(size: 14.5, weight: .semibold))
                            .monospacedDigit()
                    } else {
                        Text("measuring…").font(.system(size: 11.5)).foregroundStyle(.secondary)
                    }
                }

                if let s = state.size, s > 0 {
                    MiniBar(fraction: Double(s) / Double(maxSize))
                }

                Text(state.target.note + (state.count > 0 ? " · \(state.count) items" : ""))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button(isOpen ? "hide paths" : "show what gets deleted") {
                        toggleOpen()
                    }
                    .buttonStyle(.link).font(.system(size: 11.5))

                    if (state.size ?? 0) > 0 {
                        Button("Clean this", action: onCleanOne)
                            .buttonStyle(.bordered).controlSize(.small).tint(.riskReview)
                    }
                }

                if isOpen { pathList }
            }
        }
        .padding(.trailing, 14).padding(.vertical, 12).padding(.leading, 0)
        .glassSurface(radius: 13, selected: state.selected)
        .opacity(state.busy ? 0.55 : 1)
    }

    // ------------------------------------------------------------------
    // Expanded contents
    //
    // Was a wall of monospaced paths. A path is not what you recognise a file
    // by — the name is. Name leads, location is secondary, and per-row
    // selection means you can clear several without hunting one X at a time.
    // ------------------------------------------------------------------

    private var pathList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let entries = app.pathsFor[state.id] {
                if entries.isEmpty {
                    Text("Runs a command — there is no direct file list to show.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    pathHeader(entries)
                    Divider().opacity(0.5)
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { i, e in
                                pathRow(e, striped: i.isMultiple(of: 2))
                            }
                        }
                    }
                    .frame(maxHeight: entries.count > 8 ? 260 : .infinity)
                }
            } else {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.small)
                    Text("Reading contents…").font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.07)))
    }

    private func pathHeader(_ entries: [PathEntry]) -> some View {
        HStack(spacing: 8) {
            Text("\(entries.count) item\(entries.count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .semibold))
            Text(fmtBytes(entries.reduce(0) { $0 + $1.size }))
                .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                .foregroundStyle(.secondary)

            Spacer()

            if !picked.isEmpty {
                Text("\(picked.count) selected")
                    .font(.system(size: 10.5)).foregroundStyle(.secondary)
                Button {
                    let doomed = entries.filter { picked.contains($0.path) }
                    picked.removeAll()
                    Task { for e in doomed { await app.deletePath(e, in: state.id) } }
                } label: {
                    Text("Delete selected").font(.system(size: 10.5, weight: .semibold))
                }
                .buttonStyle(.borderless).foregroundStyle(Color.riskReview)
                Button("Clear") { picked.removeAll() }
                    .buttonStyle(.borderless).font(.system(size: 10.5))
            } else {
                Button {
                    picked = Set(entries.map(\.path))
                } label: {
                    Text("Select all").font(.system(size: 10.5))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.bottom, 7)
    }

    private func pathRow(_ e: PathEntry, striped: Bool) -> some View {
        let isPicked = picked.contains(e.path)
        let name = (e.path as NSString).lastPathComponent
        let folder = tilde((e.path as NSString).deletingLastPathComponent)

        return HStack(spacing: 9) {
            Toggle("", isOn: Binding(
                get: { isPicked },
                set: { on in if on { picked.insert(e.path) } else { picked.remove(e.path) } }
            ))
            .labelsHidden().toggleStyle(.checkbox)

            Image(systemName: Self.icon(for: e.path))
                .font(.system(size: 12))
                .foregroundStyle(Self.tint(for: e.path))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1).truncationMode(.middle)
                Text(folder)
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.head)
            }

            Spacer(minLength: 8)

            Text(fmtBytes(e.size))
                .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                .foregroundStyle(.secondary)

            Button { Explore.reveal(e.path) } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 10.5))
            }
            .buttonStyle(.borderless).help("Reveal in Finder")

            Button { Task { await app.deletePath(e, in: state.id) } } label: {
                Image(systemName: "trash").font(.system(size: 10.5))
            }
            .buttonStyle(.borderless).foregroundStyle(Color.riskReview)
            .help("Delete this one")
        }
        .padding(.horizontal, 7).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isPicked ? Color.brand.opacity(0.12)
                               : (striped ? Color.primary.opacity(0.025) : .clear))
        )
    }

    /// Recognisable at a glance beats reading a file extension.
    private static func icon(for path: String) -> String {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        if isDir.boolValue { return "folder.fill" }
        switch (path as NSString).pathExtension.lowercased() {
        case "dmg", "iso":                  return "opticaldiscdrive.fill"
        case "pkg", "mpkg":                 return "shippingbox.fill"
        case "zip", "gz", "tar", "bz2":     return "doc.zipper"
        case "png", "jpg", "jpeg", "heic", "gif": return "photo.fill"
        case "mp4", "mov", "avi", "mkv":    return "film.fill"
        case "log", "txt":                  return "doc.text.fill"
        case "app":                         return "app.fill"
        default:                            return "doc.fill"
        }
    }

    private static func tint(for path: String) -> Color {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        if isDir.boolValue { return .series(1) }
        switch (path as NSString).pathExtension.lowercased() {
        case "dmg", "iso", "pkg", "mpkg":   return .series(2)
        case "zip", "gz", "tar", "bz2":     return .series(4)
        case "png", "jpg", "jpeg", "heic", "gif": return .series(5)
        case "mp4", "mov", "avi", "mkv":    return .series(7)
        default:                            return .secondary
        }
    }

    private func toggleOpen() {
        if isOpen {
            app.expanded.remove(state.id)
        } else {
            app.expanded.insert(state.id)
            if app.pathsFor[state.id] == nil {
                Task { await app.loadPaths(for: state) }
            }
        }
    }
}
