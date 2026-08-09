import SwiftUI

@main
struct DiskCleanerApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        Window("Disk Cleaner", id: "main") {
            ContentView()
                .environmentObject(app)
                .frame(minWidth: 720, minHeight: 520)
                .onAppear { app.start() }
        }
        .defaultSize(width: 940, height: 800)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Rescan") { Task { await app.scan() } }
                    .keyboardShortcut("r")
                Divider()
                Button("Clean") { app.page = .clean }.keyboardShortcut("1")
                Button("Explore") { app.page = .explore }.keyboardShortcut("2")
                Button("Apps") { app.page = .apps }.keyboardShortcut("3")
                Button("Duplicates") { app.page = .duplicates }.keyboardShortcut("4")
                Button("Maintenance") { app.page = .maintenance }.keyboardShortcut("5")
                Button("Activity") { app.page = .activity }.keyboardShortcut("6")
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            // Liquid Glass is a lensing material: it refracts whatever sits
            // behind it. Over a flat opaque fill it renders as an ordinary card,
            // so the window gets a real backdrop for the glass to work against.
            Backdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    GlassTabBar(selection: $app.page)
                        .padding(.vertical, 12)

                    switch app.page {
                    case .clean:       CleanView()
                    case .explore:     ExploreView()
                    case .apps:        AppsView()
                    case .duplicates:  DuplicatesView()
                    case .maintenance: MaintenanceView()
                    case .activity:    ActivityView()
                    }
                }
                .padding(20)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }

            if let toast = app.toast {
                Toast(text: toast).padding(.bottom, 22)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: app.toast)
    }

    private var hero: some View {
        HStack(spacing: 22) {
            GaugeRing(used: app.disk.usedFraction,
                      saving: app.disk.total > 0
                        ? Double(app.selectedBytes) / Double(app.disk.total) : 0,
                      label: fmtBytes(app.disk.free),
                      caption: "FREE")

            VStack(alignment: .leading, spacing: 3) {
                Text("Disk Cleaner")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                Text(tagline)
                    .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 12)

                HStack(spacing: 8) {
                    pill(fmtBytes(app.disk.total), "capacity")
                    pill(fmtBytes(app.reclaimable), "reclaimable")
                    pill(fmtBytes(app.selectedBytes), "selected")
                    pill(fmtBytes(app.freeAfter), "free after")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .background(
            LinearGradient(colors: [.brand, .brand2],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var tagline: String {
        let pct = Int((app.disk.usedFraction * 100).rounded())
        if pct > 92 { return "\(pct)% full — critically low, clean something soon" }
        if pct > 82 { return "\(pct)% full — worth clearing space" }
        return "\(pct)% full — you're in good shape"
    }

    private func pill(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: 16, weight: .semibold)).monospacedDigit()
            Text(caption.uppercased()).font(.system(size: 9, weight: .medium)).tracking(0.7)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .frame(minWidth: 92, alignment: .leading)
        .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Color.white.opacity(0.2)))
    }
}
