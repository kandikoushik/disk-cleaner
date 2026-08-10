import SwiftUI

@main
struct DiskCleanerApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        Window("Disk Cleaner", id: "main") {
            ContentView()
                .environmentObject(app)
                .frame(minWidth: 560, minHeight: 480)
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
                Button("Space Lens") { app.page = .spacelens }.keyboardShortcut("3")
                Button("Apps") { app.page = .apps }.keyboardShortcut("4")
                Button("Duplicates") { app.page = .duplicates }.keyboardShortcut("5")
                Button("Privacy") { app.page = .privacy }.keyboardShortcut("6")
                Button("Shredder") { app.page = .shredder }.keyboardShortcut("7")
                Button("Maintenance") { app.page = .maintenance }.keyboardShortcut("8")
                Button("Activity") { app.page = .activity }.keyboardShortcut("9")
            }
        }

        MenuBarExtra("Disk Cleaner", systemImage: "sparkles") {
            StatusMenuView()
                .environmentObject(app)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            Backdrop()

            HStack(spacing: 0) {
                // Left Navigation Sidebar (Categorized Menu Groups)
                VStack(alignment: .leading, spacing: 14) {
                    // App Title Header
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.brand)
                        Text("Disk Cleaner")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .padding(.horizontal, 14).padding(.top, 14)

                    Divider()

                    // Categorized Menu Items
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            menuSection("CLEANUP & STORAGE", pages: [.clean, .apps, .duplicates, .privacy, .shredder])
                            menuSection("ANALYTICS & MAPS", pages: [.explore, .spacelens, .activity])
                            menuSection("SYSTEM & TOOLS", pages: [.maintenance, .devices, .system, .settings])
                        }
                        .padding(.horizontal, 10)
                    }

                    Spacer()

                    Divider()

                    // Left Sidebar Footer
                    DyuthiFooter()
                        .padding(.horizontal, 10).padding(.bottom, 12)
                }
                .frame(width: 220)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                .overlay(Rectangle().fill(Color.hairline).frame(width: 1), alignment: .trailing)

                // Right Main Area (100% Width Expansion)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        BreadcrumbsView()

                        hero

                        Group {
                            switch app.page {
                            case .clean:       CleanView()
                            case .explore:     ExploreView()
                            case .spacelens:   SpaceLensView()
                            case .apps:        AppsView()
                            case .duplicates:  DuplicatesView()
                            case .privacy:     PrivacyView()
                            case .shredder:    ShredderView()
                            case .maintenance: MaintenanceView()
                            case .activity:    ActivityView()
                            case .devices:     DevicesView()
                            case .system:      SystemView()
                            case .settings:    SettingsView()
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: app.page)
                    }
                    .padding(18)
                }
            }

            if let toast = app.toast {
                Toast(text: toast).padding(.bottom, 36)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: app.toast)
    }

    private func menuSection(_ header: String, pages: [Page]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(header)
                .font(.system(size: 9.5, weight: .bold)).tracking(0.6)
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 10).padding(.bottom, 2)

            ForEach(pages, id: \.self) { p in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        app.page = p
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: p.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 18)
                            .foregroundStyle(app.page == p ? Color.white : Color.brand)

                        Text(p.rawValue)
                            .font(.system(size: 13, weight: app.page == p ? .bold : .medium))

                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(
                        app.page == p
                            ? LinearGradient(colors: [.brand, .brand2], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.clear, .clear], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .foregroundStyle(app.page == p ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 16) {
            // Disk Gauge & Tagline
            HStack(spacing: 12) {
                GaugeRing(used: app.disk.usedFraction,
                          saving: app.disk.total > 0
                            ? Double(app.selectedBytes) / Double(app.disk.total) : 0,
                          label: fmtBytes(app.disk.free),
                          caption: "FREE",
                          size: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Disk Cleaner")
                        .font(.system(size: 15, weight: .bold))
                    Text(tagline)
                        .font(.system(size: 11)).foregroundStyle(Color.secondary)
                }
            }

            Spacer(minLength: 8)

            // User Profile Header
            UserHeroHeader()

            Spacer(minLength: 8)

            // Capacity Stats Pills
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { heroPills }
                HStack(spacing: 6) {
                    pill(fmtBytes(app.disk.total), "capacity")
                    pill(fmtBytes(app.reclaimable), "reclaimable")
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.brand.opacity(0.2), lineWidth: 1))
        )
    }

    @ViewBuilder
    private var heroPills: some View {
        pill(fmtBytes(app.disk.total), "capacity")
        pill(fmtBytes(app.reclaimable), "reclaimable")
        pill(fmtBytes(app.selectedBytes), "selected")
        pill(fmtBytes(app.freeAfter), "free after")
    }

    private var tagline: String {
        let pct = Int((app.disk.usedFraction * 100).rounded())
        if pct > 92 { return "\(pct)% full — critically low" }
        if pct > 82 { return "\(pct)% full — clear space" }
        return "\(pct)% full — good shape"
    }

    private func pill(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: 12.5, weight: .bold)).monospacedDigit()
            Text(caption.uppercased()).font(.system(size: 8, weight: .semibold)).tracking(0.6)
                .foregroundStyle(Color.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .frame(minWidth: 72, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.hairline))
    }
}

struct UserHeroHeader: View {
    @State private var avatarData: Data? = nil

    var body: some View {
        HStack(spacing: 9) {
            Group {
                if let data = avatarData, let image = NSImage(data: data) {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Circle().fill(Color.brand.opacity(0.2))
                        .overlay(Text("👤").font(.system(size: 14)))
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.brand.opacity(0.4), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.1), radius: 3)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(NSFullUserName().isEmpty ? "Kandi Koushik" : NSFullUserName())
                        .font(.system(size: 12.5, weight: .bold))
                    Text("ADMIN").font(.system(size: 7.5, weight: .bold))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.orange.opacity(0.25), in: Capsule())
                        .foregroundStyle(Color.orange)
                }

                Text("Mac mini (M4) · macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
                    .font(.system(size: 10)).foregroundStyle(Color.secondary)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        .onAppear {
            Task {
                let data = SystemInfo.avatar(for: NSUserName())
                await MainActor.run { self.avatarData = data }
            }
        }
    }
}

/// Permanent, non-null, immutable brand signature footer for Dyuthi Tech Solutions.
struct DyuthiFooter: View {
    var body: some View {
        HStack(spacing: 7) {
            // Text and icon come from the verified source, so editing the
            // literal here alone changes nothing: the hash check still fails
            // and every destructive path stays disabled.
            Image(systemName: Attribution.verified
                  ? "shield.checkmark.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Attribution.verified ? Color.brand : Color.riskReview)
            Text(Attribution.verified ? Attribution.line : Attribution.tamperNotice)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(Attribution.verified
                                 ? Color.primary.opacity(0.85) : Color.riskReview)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassCapsule()
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        .frame(maxWidth: .infinity)
    }
}
