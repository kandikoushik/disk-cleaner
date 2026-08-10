import SwiftUI
import AppKit

// ---------------------------------------------------------------------------
// Palette
//
// The categorical slots are the validated eight-hue set: assigned in fixed
// order, never cycled, with a dark step chosen for the dark surface rather
// than an automatic flip.
// ---------------------------------------------------------------------------

extension Color {
    static func dynamic(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    static let brand  = Color.dynamic(light: "3b6cf6", dark: "5d8bff")
    static let brand2 = Color.dynamic(light: "7a5cf0", dark: "9b7bff")

    static let riskSafe    = Color.dynamic(light: "0f9d58", dark: "3ddc97")
    static let riskRebuild = Color.dynamic(light: "b8770c", dark: "f0b13c")
    static let riskReview  = Color.dynamic(light: "d63c26", dark: "ff7a63")

    static let hairline = Color.dynamic(light: "e6eaf1", dark: "222a36")
    static let track    = Color.dynamic(light: "eaeef5", dark: "222a36")
    static let neutralFill = Color.dynamic(light: "d3dae6", dark: "2c3644")
    static let sunk     = Color.dynamic(light: "f7f9fc", dark: "0f141d")

    static let inkSecondary = Color.dynamic(light: "4a5462", dark: "aab4c2")
    static let inkTertiary  = Color.dynamic(light: "6b7583", dark: "8d97a5")

    static func series(_ slot: Int) -> Color {
        let light = ["2a78d6", "eb6834", "1baf7a", "eda100",
                     "e87ba4", "008300", "4a3aa7", "e34948"]
        let dark  = ["3987e5", "d95926", "199e70", "c98500",
                     "d55181", "008300", "9085e9", "e66767"]
        let i = max(0, min(slot - 1, 7))
        return .dynamic(light: light[i], dark: dark[i])
    }
}

extension NSColor {
    convenience init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self.init(srgbRed: CGFloat((v >> 16) & 0xff) / 255,
                  green: CGFloat((v >> 8) & 0xff) / 255,
                  blue: CGFloat(v & 0xff) / 255, alpha: 1)
    }
}

extension Risk {
    var color: Color {
        switch self {
        case .safe: return .riskSafe
        case .rebuild: return .riskRebuild
        case .review: return .riskReview
        }
    }
}

// ---------------------------------------------------------------------------
// Charts
// ---------------------------------------------------------------------------

/// Free-space ring. The lighter arc previews what the current selection frees.
struct GaugeRing: View {
    let used: Double
    let saving: Double
    let label: String
    let caption: String
    var size: CGFloat = 122

    var body: some View {
        let strokeWidth = size * (11.0 / 122.0)
        let fontSize = size * (23.0 / 122.0)
        let captionSize = size * (9.5 / 122.0)

        ZStack {
            Circle().stroke(Color.brand.opacity(0.25), lineWidth: strokeWidth)
            Circle()
                .trim(from: 0, to: used)
                .stroke(LinearGradient(colors: [.brand, .brand2], startPoint: .top, endPoint: .bottom), style: .init(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0, to: max(0, used - saving))
                .stroke(Color.riskSafe, style: .init(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: used - saving)
            VStack(spacing: 1) {
                Text(label).font(.system(size: max(11, fontSize), weight: .bold)).monospacedDigit()
                Text(caption).font(.system(size: max(7, captionSize), weight: .semibold))
                    .tracking(1).opacity(0.85)
            }
            .foregroundStyle(Color.primary)
        }
        .frame(width: size, height: size)
    }
}

struct StackSegment: Identifiable {
    let id: String
    let size: Int64
    let color: Color
}

/// Proportional stacked bar with a 2px gap between segments.
struct StackedBar: View {
    let segments: [StackSegment]
    var height: CGFloat = 24

    @State private var hoveredId: String? = nil

    var total: Int64 { max(segments.reduce(0) { $0 + $1.size }, 1) }

    var body: some View {
        GeometryReader { geo in
            let gaps = CGFloat(max(0, segments.count - 1)) * 2
            let minima = CGFloat(segments.count) * 2
            let usable = max(0, geo.size.width - gaps - minima)

            HStack(spacing: 2) {
                ForEach(segments) { s in
                    let pct = (Double(s.size) / Double(total)) * 100
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(s.color)
                        .frame(width: 2 + usable * CGFloat(s.size) / CGFloat(total))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(hoveredId == s.id ? Color.white : Color.clear, lineWidth: 1.5)
                        )
                        .onHover { isHovered in
                            hoveredId = isHovered ? s.id : nil
                        }
                        .popover(isPresented: Binding(
                            get: { hoveredId == s.id },
                            set: { if !$0 { hoveredId = nil } }
                        ), arrowEdge: .bottom) {
                            HStack(spacing: 8) {
                                Circle().fill(s.color).frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.id)
                                        .font(.system(size: 12, weight: .bold))
                                    Text("\(fmtBytes(s.size)) · \(String(format: "%.1f%%", pct)) of disk")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                        }
                }
            }
            .frame(width: geo.size.width, height: height, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.track))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .animation(.easeInOut(duration: 0.6), value: total)
    }
}

/// Legend: a colour chip beside the name, with the value in text ink — never a
/// number coloured by its own series.
struct LegendRow: View {
    let items: [(name: String, size: Int64, color: Color)]
    var onTap: ((String) -> Void)? = nil

    let columns = [GridItem(.adaptive(minimum: 132), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
            ForEach(items, id: \.name) { item in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(item.color)
                        .frame(width: 9, height: 9)
                    Text(item.name).font(.system(size: 11)).foregroundStyle(Color.inkSecondary)
                    Text(fmtBytes(item.size)).font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .onTapGesture { onTap?(item.name) }
            }
        }
    }
}

/// Free space over time.
struct Sparkline: View {
    let samples: [HistorySample]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let values = samples.map { Double($0.free) }
            let lo = values.min() ?? 0, hi = values.max() ?? 1
            let span = max(hi - lo, 1)
            let pts = values.enumerated().map { i, v in
                CGPoint(x: w * Double(i) / Double(max(values.count - 1, 1)),
                        y: h - 10 - (v - lo) / span * (h - 22))
            }
            ZStack {
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: CGPoint(x: first.x, y: h))
                    pts.forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: pts.last!.x, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [.brand.opacity(0.26), .brand.opacity(0)],
                                     startPoint: .top, endPoint: .bottom))
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    pts.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(Color.brand, style: .init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                if let last = pts.last {
                    Circle().fill(Color.brand).frame(width: 7, height: 7)
                        .position(last)
                }
            }
        }
        .frame(height: 74)
    }
}

// ---------------------------------------------------------------------------
// Shared chrome
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Liquid Glass
//
// macOS 26 draws real glass — refraction, specular edge, adaptive tint. On
// anything older the same surfaces fall back to an opaque card, so one code
// path covers both without the layout shifting.
// ---------------------------------------------------------------------------

struct GlassSurface: ViewModifier {
    var radius: CGFloat = 14
    var selected: Bool = false

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                )
                .glassEffect(
                    selected ? .regular.tint(.brand.opacity(0.22)).interactive()
                             : .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(selected ? Color.brand.opacity(0.7) : Color.primary.opacity(0.08),
                                      lineWidth: 1)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(selected ? Color.brand : Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

extension View {
    func glassSurface(radius: CGFloat = 14, selected: Bool = false) -> some View {
        modifier(GlassSurface(radius: radius, selected: selected))
    }

    /// Glass capsule buttons where the OS supports them.
    @ViewBuilder func glassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.glass) }
        } else {
            if prominent { self.buttonStyle(.borderedProminent) } else { self.buttonStyle(.bordered) }
        }
    }

    /// Groups nearby glass shapes so they blend instead of stacking.
    @ViewBuilder func glassGroup(spacing: CGFloat = 8) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
    }
}

/// Soft colour field behind the whole window. Without this the glass has
/// nothing to bend and looks like a flat card.
/// Refined Apple Liquid Glass Backdrop. Provides ambient gradient depth for glass surfaces
/// without continuous background motion distraction.
struct Backdrop: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            Rectangle().fill(Color(nsColor: .windowBackgroundColor))

            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let (c1, c2, c3) = app.theme.colors

                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [c1.opacity(0.18), .clear],
                                             center: .center, startRadius: 0, endRadius: w * 0.55))
                        .frame(width: w * 1.1, height: w * 1.1)
                        .position(x: w * 0.10, y: h * 0.06)

                    Circle()
                        .fill(RadialGradient(colors: [c2.opacity(0.15), .clear],
                                             center: .center, startRadius: 0, endRadius: w * 0.55))
                        .frame(width: w * 1.1, height: w * 1.1)
                        .position(x: w * 0.92, y: h * 0.10)

                    Circle()
                        .fill(RadialGradient(colors: [c3.opacity(0.10), .clear],
                                             center: .center, startRadius: 0, endRadius: w * 0.45))
                        .frame(width: w * 0.9, height: w * 0.9)
                        .position(x: w * 0.40, y: h * 0.70)
                }
            }
            .blur(radius: 45)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Glass Breadcrumbs Trail Header Component
struct BreadcrumbsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.brand)
            Text("Disk Cleaner")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.inkSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary.opacity(0.6))
            Text(app.page.rawValue)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(Color.brand)

            if let cat = app.categoryFilter {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.6))
                Text(cat.rawValue)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Color.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .glassCapsule()
    }
}

/// Refined Liquid Glass Card Component
struct Card<Content: View>: View {
    var radius: CGFloat = 14
    @State private var isHovered = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .glassSurface(radius: radius, selected: isHovered)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { h in isHovered = h }
    }
}

// ---------------------------------------------------------------------------
// Glass tab bar
//
// A stock `.pickerStyle(.segmented)` keeps AppKit's own segmented control and
// never becomes glass. This is the hand-built equivalent: one glass container,
// with the selected pill carrying a `glassEffectID` so the highlight *morphs*
// between tabs — the signature Liquid Glass motion — instead of cross-fading.
// ---------------------------------------------------------------------------

/// How much text the tab bar can afford at the current width.
enum TabLabelMode {
    case all        // every tab shows its name
    case activeOnly // only the selected tab shows its name
    case none       // icons only
}

struct GlassTabBar: View {
    @EnvironmentObject var app: AppState
    @Binding var selection: Page
    @Namespace private var pillSpace

    var body: some View {
        ViewThatFits(in: .horizontal) {
            bar(.all)
            bar(.activeOnly)
            bar(.none)
            ScrollView(.horizontal, showsIndicators: false) {
                bar(.activeOnly).padding(.horizontal, 2)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.76), value: selection)
    }

    @ViewBuilder
    private func bar(_ mode: TabLabelMode) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 2) {
                    ForEach(app.orderedPages) { page in
                        tab(page, mode: mode)
                            .background {
                                if selection == page {
                                    Capsule()
                                        .fill(Color.brand.opacity(0.001))
                                        .glassEffect(.regular.tint(.brand.opacity(0.35))
                                            .interactive(), in: Capsule())
                                        .glassEffectID(page.id, in: pillSpace)
                                }
                            }
                    }
                }
                .padding(4)
                .glassEffect(.regular, in: Capsule())
            }
            .fixedSize()
        } else {
            HStack(spacing: 2) {
                ForEach(app.orderedPages) { page in
                    tab(page, mode: mode)
                        .background {
                            if selection == page {
                                Capsule().fill(Color.brand.opacity(0.18))
                            }
                        }
                }
            }
            .padding(4)
            .background(Capsule().fill(Color.sunk))
            .overlay(Capsule().strokeBorder(Color.hairline))
            .fixedSize()
        }
    }

    private func tab(_ page: Page, mode: TabLabelMode) -> some View {
        let isActive = selection == page
        let showsLabel: Bool = {
            switch mode {
            case .all:        return true
            case .activeOnly: return isActive
            case .none:       return false
            }
        }()

        return Button {
            selection = page
        } label: {
            HStack(spacing: 5) {
                Image(systemName: page.icon).font(.system(size: 11, weight: .semibold))
                if showsLabel {
                    Text(page.rawValue).font(.system(size: 12.5, weight: .medium))
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .frame(minWidth: showsLabel ? 0 : 30)
            .padding(.horizontal, showsLabel ? 11 : 8).padding(.vertical, 7)
            .foregroundStyle(isActive ? Color.primary : Color.secondary)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(page.rawValue)
    }
}

/// Glass field for search and other inline inputs.
struct GlassField<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(.horizontal, 11).padding(.vertical, 7)
            .glassSurface(radius: 9)
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String = ""
    var body: some View {
        HStack(spacing: 9) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold)).tracking(0.9)
                .foregroundStyle(Color.inkSecondary)
            if !trailing.isEmpty {
                Text(trailing).font(.system(size: 11, weight: .semibold)).monospacedDigit()
            }
            Rectangle().fill(Color.hairline).frame(height: 1)
        }
        .padding(.top, 14).padding(.bottom, 6)
    }
}

struct RiskTag: View {
    let risk: Risk
    @State private var showingPopover = false

    var tooltipMessage: String {
        switch risk {
        case .safe:
            return "100% Safe Cache — Completely safe to delete. System or apps will automatically recreate files when needed."
        case .rebuild:
            return "Rebuild Required — Safe to clean, but target application may take extra seconds to rebuild caches on next launch."
        case .review:
            return "User Review Advised — Contains user data, project files, or app state. Verify contents before deleting."
        }
    }

    var body: some View {
        Button {
            showingPopover.toggle()
        } label: {
            HStack(spacing: 3) {
                Text(risk.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold)).tracking(0.6)
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 8))
            }
            .padding(.horizontal, 6).padding(.vertical, 2.5)
            .background(risk.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(risk.color)
        }
        .buttonStyle(.plain)
        .help(tooltipMessage)
        .popover(isPresented: $showingPopover, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(risk.rawValue.uppercased() + " SAFETY RISK")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(risk.color)
                    Spacer()
                }
                Text(tooltipMessage)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.inkSecondary)
            }
            .padding(12)
            .frame(width: 260)
        }
    }
}

struct MiniBar: View {
    let fraction: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.track)
                Capsule()
                    .fill(LinearGradient(colors: [.brand, .brand2],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(3, geo.size.width * min(max(fraction, 0.015), 1)))
            }
        }
        .frame(height: 5)
    }
}

struct Toast: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .medium))
            .padding(.horizontal, 18).padding(.vertical, 10)
            .glassCapsule()
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// ---------------------------------------------------------------------------
// Small glass helpers
// ---------------------------------------------------------------------------

extension View {
    /// Pill used for the category filters.
    @ViewBuilder func glassChip(active: Bool) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(active ? .regular.tint(.brand.opacity(0.4)).interactive()
                                    : .regular.interactive(), in: Capsule())
        } else {
            self.background(active ? Color.brand.opacity(0.18) : Color.clear, in: Capsule())
                .overlay(Capsule().strokeBorder(active ? Color.clear : Color.hairline))
        }
    }

    @ViewBuilder func glassCapsule() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: Capsule())
        } else {
            self.background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.hairline))
        }
    }
}
