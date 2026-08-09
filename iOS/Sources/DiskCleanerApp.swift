import SwiftUI

@main
struct DiskCleanerIOSApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

enum MobileTab: String, CaseIterable, Identifiable {
    case clean = "Clean"
    case explore = "Explore"
    case spaceLens = "Space Lens"
    case apps = "Apps"
    case duplicates = "Duplicates"
    case privacy = "Privacy"
    case shredder = "Shredder"
    case maintenance = "Maintenance"
    case settings = "Settings"
    case devices = "Devices"
    case system = "System"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .clean: return "sparkles"
        case .explore: return "chart.pie.fill"
        case .spaceLens: return "sun.max.fill"
        case .apps: return "app.badge.fill"
        case .duplicates: return "doc.on.doc.fill"
        case .privacy: return "hand.raised.fill"
        case .shredder: return "xmark.bin.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .settings: return "gearshape.fill"
        case .devices: return "cable.connector"
        case .system: return "laptopcomputer"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: MobileTab = .clean

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top Page Selector Carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MobileTab.allCases) { tab in
                            Button(action: { selectedTab = tab }) {
                                HStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                    Text(tab.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedTab == tab ? Color.blue : Color(UIColor.tertiarySystemFill))
                                .foregroundColor(selectedTab == tab ? .white : .primary)
                                .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(UIColor.secondarySystemBackground))

                // Page Content
                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case .clean: MobileCleanView()
                        case .explore: MobileExploreView()
                        case .spaceLens: MobileSpaceLensView()
                        case .apps: MobileAppsView()
                        case .duplicates: MobileDuplicatesView()
                        case .privacy: MobilePrivacyView()
                        case .shredder: MobileShredderView()
                        case .maintenance: MobileMaintenanceView()
                        case .settings: MobileSettingsView()
                        case .devices: MobileDevicesView()
                        case .system: MobileSystemView()
                        }

                        // Non-removable mandatory footer
                        VStack(spacing: 4) {
                            Divider().padding(.vertical, 8)
                            Text("Disk Cleaner Native v2.0")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Built by Dyuthi Tech Solutions")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        .padding(.bottom, 20)
                    }
                    .padding()
                }
            }
            .navigationTitle("Disk Cleaner iOS")
        }
    }
}

// 1. Clean View
struct MobileCleanView: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().stroke(Color.blue.opacity(0.2), lineWidth: 14).frame(width: 130, height: 130)
                Circle().trim(from: 0, to: 0.68).stroke(Color.blue, style: StrokeStyle(lineWidth: 14, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 130, height: 130)
                VStack {
                    Text("68%").font(.title.bold())
                    Text("Storage Used").font(.caption).foregroundColor(.secondary)
                }
            }
            MobileCard(title: "Reclaimable Storage", subtitle: "4.2 GB across 8 categories") {
                VStack(spacing: 8) {
                    TargetRowItem(title: "Photo & Video Thumbnails", size: "1.8 GB")
                    TargetRowItem(title: "Safari Web Cache", size: "840 MB")
                    TargetRowItem(title: "Offloaded App Caches", size: "1.2 GB")
                    TargetRowItem(title: "System Logs & Crash Dumps", size: "360 MB")
                }
            }
        }
    }
}

// 2. Explore View
struct MobileExploreView: View {
    var body: some View {
        MobileCard(title: "Storage Hierarchy Explorer", subtitle: "Inspect large folders") {
            VStack(alignment: .leading, spacing: 10) {
                Text("📁 AppData / Media / Photos (14.2 GB)").font(.subheadline.bold())
                Text("📁 Offline Video Cache (8.4 GB)").font(.subheadline.bold())
                Text("📁 System Downloads & Temp (3.1 GB)").font(.subheadline.bold())
            }
        }
    }
}

// 3. Space Lens View
struct MobileSpaceLensView: View {
    var body: some View {
        MobileCard(title: "Space Lens Visual Storage Map", subtitle: "Proportional bubble breakdown") {
            VStack(spacing: 12) {
                HStack {
                    Text("🔴 Photos (14.2 GB)").bold()
                    Spacer()
                    Text("🔵 Videos (8.4 GB)").bold()
                }
                HStack {
                    Text("🟢 App Caches (5.1 GB)").bold()
                    Spacer()
                    Text("🟡 System (3.1 GB)").bold()
                }
            }
        }
    }
}

// 4. Apps View
struct MobileAppsView: View {
    var body: some View {
        MobileCard(title: "App Cache & Storage Inspector", subtitle: "Offload unused apps") {
            VStack(spacing: 8) {
                TargetRowItem(title: "Social Media App Cache", size: "2.4 GB")
                TargetRowItem(title: "Offline Maps & Navigation", size: "1.1 GB")
            }
        }
    }
}

// 5. Duplicates View
struct MobileDuplicatesView: View {
    var body: some View {
        MobileCard(title: "Duplicate File & Photo Finder", subtitle: "Identical hashes detected") {
            VStack(spacing: 8) {
                TargetRowItem(title: "Duplicate Burst Photos (14 items)", size: "420 MB")
                TargetRowItem(title: "Duplicate Downloaded PDFs", size: "120 MB")
            }
        }
    }
}

// 6. Privacy View
struct MobilePrivacyView: View {
    var body: some View {
        MobileCard(title: "Privacy & Safari Data Wiper", subtitle: "Clear history and cookies") {
            VStack(spacing: 8) {
                TargetRowItem(title: "Safari Browsing History", size: "45 MB")
                TargetRowItem(title: "Web Service Worker Caches", size: "310 MB")
            }
        }
    }
}

// 7. Shredder View
struct MobileShredderView: View {
    var body: some View {
        MobileCard(title: "Secure File Shredder", subtitle: "Permanently overwrite bytes") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Select any sensitive file to shred irrecoverably.")
                    .font(.caption).foregroundColor(.secondary)
                Button("Select Mobile File to Shred") { }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

// 8. Maintenance View
struct MobileMaintenanceView: View {
    var body: some View {
        MobileCard(title: "Mobile System Maintenance", subtitle: "RAM Memory & System optimization") {
            VStack(spacing: 10) {
                Button("⚡ Purge Inactive RAM Memory") { }
                    .buttonStyle(.borderedProminent)
                Button("Flush DNS Resolver Cache") { }
                    .buttonStyle(.bordered)
            }
        }
    }
}

// 9. Settings View
struct MobileSettingsView: View {
    var body: some View {
        MobileCard(title: "Preferences & Customization", subtitle: "App settings") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Move items to Recently Deleted", isOn: .constant(true))
                Text("Theme: iOS Dynamic Liquid Glass")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

// 10. Devices View
struct MobileDevicesView: View {
    var body: some View {
        MobileCard(title: "Connected Devices & Accessories", subtitle: "USB & Wireless peripherals") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "laptopcomputer")
                        .font(.title2).foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("Kandi's Mac mini").font(.subheadline.bold())
                        Text("Connected via AirDrop & USB-C").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// 11. System View (Matching macOS System Page exactly!)
struct MobileSystemView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Hardware Specs
            MobileCard(title: "THIS DEVICE · HARDWARE", subtitle: "Hardware Diagnostics") {
                VStack(spacing: 8) {
                    TargetRowItem(title: "Model", size: "iPhone 16 Pro Max")
                    TargetRowItem(title: "Chip", size: "Apple A18 Pro")
                    TargetRowItem(title: "Cores", size: "6 (2 Perf + 4 Eff)")
                    TargetRowItem(title: "Memory", size: "8 GB Unified")
                    TargetRowItem(title: "Storage", size: "50 GB free of 256 GB")
                }
            }

            // Operating System Specs
            MobileCard(title: "OPERATING SYSTEM", subtitle: "iOS Release & Kernel") {
                VStack(spacing: 8) {
                    TargetRowItem(title: "iOS Version", size: "26.5.2")
                    TargetRowItem(title: "Build", size: "25F84")
                    TargetRowItem(title: "Uptime", size: "2d 20h")
                    TargetRowItem(title: "Power", size: "Battery (92% Charged)")
                }
            }

            // iOS Updates
            MobileCard(title: "IOS UPDATES", subtitle: "Apple Update Service") {
                HStack {
                    Text("System is up to date").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Button("Check now") { }.buttonStyle(.bordered)
                }
            }

            // User Account Info Card
            MobileCard(title: "ACCOUNTS", subtitle: "Active Apple ID Account") {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.blue).frame(width: 50, height: 50)
                        Text("👤").font(.title)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Kandi Koushik").font(.headline)
                            Text("YOU").font(.caption2).bold().padding(.horizontal, 4).padding(.vertical, 2).background(Color.blue.opacity(0.2)).cornerRadius(4)
                            Text("ADMIN").font(.caption2).bold().padding(.horizontal, 4).padding(.vertical, 2).background(Color.orange.opacity(0.2)).cornerRadius(4)
                            Text("SIGNED IN").font(.caption2).bold().padding(.horizontal, 4).padding(.vertical, 2).background(Color.green.opacity(0.2)).cornerRadius(4)
                        }
                        Text("@kandikoushik").font(.caption).foregroundColor(.secondary)
                        Text("USER ID: 501 · On console since Aug 6 19:17").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct MobileCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundColor(.secondary)
            Divider()
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct TargetRowItem: View {
    let title: String
    let size: String

    var body: some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text(size).font(.subheadline).bold()
        }
    }
}
