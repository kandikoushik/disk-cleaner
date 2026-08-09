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
    static let sunk     = Color.dynamic(light: "f7f9fc", dark: "0f141d")

    /// Categorical slot 1–8.
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
    let used: Double          // 0…1
    let saving: Double        // 0…1, part of `used` that would be freed
    let label: String
    let caption: String

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.22), lineWidth: 11)
            Circle()
                .trim(from: 0, to: used)
                .stroke(Color.white.opacity(0.5), style: .init(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0, to: max(0, used - saving))
                .stroke(.white, style: .init(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: used - saving)
            VStack(spacing: 2) {
                Text(label).font(.system(size: 23, weight: .bold)).monospacedDigit()
                Text(caption).font(.system(size: 9.5, weight: .semibold))
                    .tracking(1).opacity(0.85)
            }
            .foregroundStyle(.white)
        }
        .frame(width: 122, height: 122)
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

    var total: Int64 { max(segments.reduce(0) { $0 + $1.size }, 1) }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(segments) { s in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(s.color)
                        .frame(width: max(2, geo.size.width * CGFloat(s.size) / CGFloat(total)))
                        .help("\(s.id) — \(fmtBytes(s.size))")
                }
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.track))
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
                    Text(item.name).font(.system(size: 11)).foregroundStyle(.secondary)
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
                .glassEffect(
                    selected ? .regular.tint(.brand.opacity(0.22)).interactive()
                             : .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(selected ? Color.brand.opacity(0.7) : Color.clear,
                                      lineWidth: 1)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(selected ? Color.brand : Color.hairline, lineWidth: 1)
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
struct Backdrop: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Color(nsColor: .windowBackgroundColor))
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                Circle()
                    .fill(RadialGradient(colors: [.brand.opacity(0.55), .clear],
                                         center: .center, startRadius: 0, endRadius: w * 0.55))
                    .frame(width: w * 1.1, height: w * 1.1)
                    .position(x: w * 0.12, y: h * 0.04)
                Circle()
                    .fill(RadialGradient(colors: [.brand2.opacity(0.5), .clear],
                                         center: .center, startRadius: 0, endRadius: w * 0.5))
                    .frame(width: w, height: w)
                    .position(x: w * 0.95, y: h * 0.18)
                Circle()
                    .fill(RadialGradient(colors: [Color.series(3).opacity(0.3), .clear],
                                         center: .center, startRadius: 0, endRadius: w * 0.45))
                    .frame(width: w * 0.9, height: w * 0.9)
                    .position(x: w * 0.5, y: h * 0.92)
            }
            .blur(radius: 34)
        }
        .ignoresSafeArea()
    }
}

struct Card<Content: View>: View {
    var radius: CGFloat = 14
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(15).glassSurface(radius: radius)
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

struct GlassTabBar: View {
    @Binding var selection: Page
    @Namespace private var pillSpace

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(Page.allCases) { page in
                        tab(page)
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
                .padding(5)
                .glassEffect(.regular, in: Capsule())
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.76), value: selection)
        } else {
            HStack(spacing: 4) {
                ForEach(Page.allCases) { page in
                    tab(page)
                        .background {
                            if selection == page {
                                Capsule().fill(Color.brand.opacity(0.18))
                            }
                        }
                }
            }
            .padding(5)
            .background(Capsule().fill(Color.sunk))
            .overlay(Capsule().strokeBorder(Color.hairline))
            .animation(.spring(response: 0.34, dampingFraction: 0.76), value: selection)
        }
    }

    private func tab(_ page: Page) -> some View {
        Button {
            selection = page
        } label: {
            HStack(spacing: 5) {
                Image(systemName: page.icon).font(.system(size: 11, weight: .semibold))
                Text(page.rawValue).font(.system(size: 12.5, weight: .medium))
            }
            .padding(.horizontal, 13).padding(.vertical, 7)
            .foregroundStyle(selection == page ? Color.primary : Color.secondary)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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
                .foregroundStyle(.secondary)
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
    var body: some View {
        Text(risk.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold)).tracking(0.6)
            .padding(.horizontal, 6).padding(.vertical, 2.5)
            .background(risk.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(risk.color)
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
