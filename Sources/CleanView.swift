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
            filters
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
        HStack(alignment: .top, spacing: 10) {
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
        if name == "Free" { return .track }
        if name == "System & other" { return .secondary.opacity(0.55) }
        let ordered = app.composition.filter { $0.name != "Free" && $0.name != "System & other" }
        let idx = (ordered.firstIndex { $0.name == name } ?? 0) + 1
        return .series(idx)
    }

    // ---- toolbar ------------------------------------------------------------

    private var toolbar: some View {
        HStack(spacing: 7) {
            Button { Task { await app.scan(); await app.loadComposition() } } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .disabled(app.scanning)

            Button { confirming = .quick } label: {
                Label("Quick clean", systemImage: "bolt.fill")
            }
            .disabled(app.scanning || !app.states.contains { $0.target.risk == .safe && $0.hasContent })
            .tint(.riskSafe)

            Button("Select safe") { app.selectSafe() }
            Button("Select all") { app.selectAllButPersonal() }
            Button("Clear") { app.clearSelection() }

            Spacer()

            Button {
                confirming = .selection
            } label: {
                Text(app.selectedCount > 0
                     ? "Clean \(app.selectedCount) · \(fmtBytes(app.selectedBytes))"
                     : "Clean selected")
                .fontWeight(.semibold)
            }
            .glassButton(prominent: true)
            .tint(app.selectionHasReview ? .riskReview : .brand)
            .disabled(app.selectedCount == 0 || app.scanning)
        }
    }

    private var filters: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    .font(.system(size: 11))
                TextField("Search targets…", text: $app.search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
            }
            .padding(.horizontal, 11).padding(.vertical, 7)
            .glassSurface(radius: 9)
            .frame(width: 220)

            Picker("", selection: $app.sort) {
                ForEach(SortMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden().frame(width: 150)

            Spacer()
            Button("Copy report") { app.copyReport() }.glassButton()
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("Everything", active: app.categoryFilter == nil) { app.categoryFilter = nil }
                ForEach(app.liveCategories, id: \.self) { cat in
                    chip(cat.rawValue, active: app.categoryFilter == cat) {
                        app.categoryFilter = (app.categoryFilter == cat) ? nil : cat
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(_ text: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: 11.5, weight: .medium))
                .padding(.horizontal, 11).padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .glassChip(active: active)
        .foregroundStyle(active ? Color.primary : .secondary)
    }

    // ---- list ---------------------------------------------------------------

    private var targetList: some View {
        VStack(alignment: .leading, spacing: 0) {
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

    private var pathList: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let entries = app.pathsFor[state.id] {
                if entries.isEmpty {
                    Text("(runs a command — no direct path list)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                ForEach(entries) { e in
                    HStack(spacing: 8) {
                        Text(tilde(e.path)).font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 6)
                        Text(fmtBytes(e.size)).font(.system(size: 10.5, design: .monospaced))
                            .monospacedDigit()
                        Button { Explore.reveal(e.path) } label: {
                            Image(systemName: "folder")
                        }.buttonStyle(.borderless).help("Reveal in Finder")
                        Button { Task { await app.deletePath(e, in: state.id) } } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                        }.buttonStyle(.borderless).help("Delete just this")
                    }
                }
            } else {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("reading…").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.sunk))
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
