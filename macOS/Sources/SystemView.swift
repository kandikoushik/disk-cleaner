import SwiftUI

struct SystemView: View {
    @EnvironmentObject var app: AppState

    // Held locally rather than in AppState: nothing else in the app needs these,
    // and it keeps the shared state object from growing for one page.
    @State private var hardware: [InfoRow] = []
    @State private var os: [InfoRow] = []
    @State private var signedIn: [LoggedInUser] = []
    @State private var profiles: [SystemInfo.Profile] = []
    @State private var updates: [SoftwareUpdate] = []
    @State private var loading = true
    @State private var checkingUpdates = false
    @State private var checkedUpdates = false
    @State private var revealSerial = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { load() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .disabled(loading)
                if loading { ProgressView().controlSize(.small).padding(.leading, 4) }
                Spacer()
            }

            SectionHeader(title: "This Mac")
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 10) { specCards }
                VStack(alignment: .leading, spacing: 10) { specCards }
            }

            SectionHeader(title: "macOS updates",
                          trailing: checkedUpdates ? "\(updates.count) pending" : "")
            updatesCard

            SectionHeader(title: "Accounts", trailing: "\(profiles.count)")
            ForEach(profiles) { p in accountCard(p) }
        }
        .onAppear { if hardware.isEmpty { load() } }
    }

    @ViewBuilder
    private var specCards: some View {
        Group {
            Card {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Hardware").font(.system(size: 12.5, weight: .semibold))
                    ForEach(hardware) { row in infoLine(row) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Card {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Operating system").font(.system(size: 12.5, weight: .semibold))
                    ForEach(os) { row in infoLine(row) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func infoLine(_ row: InfoRow) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(row.label)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.inkSecondary)
                .frame(width: 92, alignment: .leading)

            if row.sensitive && !revealSerial {
                // Masked by default: a serial identifies the machine to Apple
                // and to warranty lookups, and screenshots travel.
                Text(String(repeating: "•", count: max(row.value.count, 8)))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                Button("Show") { revealSerial = true }
                    .buttonStyle(.borderless).font(.system(size: 10.5))
            } else {
                Text(row.value)
                    .font(.system(size: 12, weight: .medium))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if row.sensitive {
                    Button("Hide") { revealSerial = false }
                        .buttonStyle(.borderless).font(.system(size: 10.5))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var updatesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                if checkingUpdates {
                    HStack(spacing: 7) {
                        ProgressView().controlSize(.small)
                        Text("Asking Apple — this takes a moment")
                            .font(.system(size: 12)).foregroundStyle(Color.inkSecondary)
                    }
                } else if !checkedUpdates {
                    HStack {
                        Text("Not checked yet. This contacts Apple's update service.")
                            .font(.system(size: 12)).foregroundStyle(Color.inkSecondary)
                        Spacer()
                        Button("Check now") { checkUpdates() }
                    }
                } else if updates.isEmpty {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.riskSafe)
                        Text("macOS is up to date").font(.system(size: 12.5, weight: .medium))
                        Spacer()
                        Button("Check again") { checkUpdates() }
                    }
                } else {
                    ForEach(updates) { u in
                        HStack(spacing: 9) {
                            Image(systemName: u.recommended
                                  ? "exclamationmark.circle.fill" : "arrow.down.circle")
                                .foregroundStyle(u.recommended ? Color.riskRebuild : Color.brand)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(u.name).font(.system(size: 12.5, weight: .medium))
                                Text([u.version, u.size].filter { !$0.isEmpty }
                                    .joined(separator: " · "))
                                    .font(.system(size: 11)).foregroundStyle(Color.inkSecondary)
                            }
                            Spacer()
                            if u.recommended {
                                Text("RECOMMENDED")
                                    .font(.system(size: 9, weight: .bold)).tracking(0.5)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.riskRebuild.opacity(0.15),
                                                in: RoundedRectangle(cornerRadius: 4))
                                    .foregroundStyle(Color.riskRebuild)
                            }
                        }
                    }
                    Divider().opacity(0.5)
                    HStack {
                        // Installing macOS updates needs admin rights and can
                        // reboot the machine, so this hands off to Settings
                        // rather than doing it behind your back.
                        Text("Install from System Settings — updates need admin rights "
                             + "and may restart the Mac.")
                            .font(.system(size: 11)).foregroundStyle(Color.inkTertiary)
                        Spacer()
                        Button("Open Software Update") {
                            SystemInfo.openSoftwareUpdatePane()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func accountCard(_ p: SystemInfo.Profile) -> some View {
        let session = signedIn.first { $0.name == p.shortName }

        return HStack(alignment: .top, spacing: 14) {
            avatarView(p)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(p.fullName.capitalized)
                        .font(.system(size: 15, weight: .semibold))
                    if p.shortName == NSUserName() { badge("YOU", .brand) }
                    if p.isAdmin { badge("ADMIN", .riskRebuild) }
                    if session != nil { badge("SIGNED IN", .riskSafe) }
                }

                Text("@\(p.shortName)")
                    .font(.system(size: 12)).foregroundStyle(Color.inkSecondary)

                HStack(spacing: 16) {
                    detail("Home", tilde(p.home))
                    detail("Shell", (p.shell as NSString).lastPathComponent)
                    detail("User ID", p.uid)
                }
                .padding(.top, 2)

                if let session {
                    Text("On \(session.terminal) since \(session.since)")
                        .font(.system(size: 11)).foregroundStyle(Color.inkTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .glassSurface(radius: 13)
        .padding(.bottom, 8)
    }

    /// Account picture when macOS has one, otherwise initials on the brand
    /// gradient — never an empty grey circle.
    private func avatarView(_ p: SystemInfo.Profile) -> some View {
        Group {
            if let data = p.avatar, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [.brand, .brand2],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(
                        Text(initials(p.fullName))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text).font(.system(size: 8.5, weight: .bold)).tracking(0.5)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 8.5, weight: .semibold)).tracking(0.5)
                .foregroundStyle(Color.inkTertiary)
            Text(value).font(.system(size: 11, weight: .medium))
                .lineLimit(1).truncationMode(.middle)
        }
    }

    // ------------------------------------------------------------------

    private func load() {
        loading = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                (SystemInfo.hardware(), SystemInfo.operatingSystem(),
                 SystemInfo.users(), SystemInfo.profiles())
            }.value
            hardware = result.0
            os = result.1
            signedIn = result.2
            profiles = result.3
            loading = false
        }
    }

    private func checkUpdates() {
        checkingUpdates = true
        Task {
            let found = await Task.detached(priority: .userInitiated) {
                SystemInfo.pendingUpdates()
            }.value
            updates = found
            checkingUpdates = false
            checkedUpdates = true
            app.say(found.isEmpty ? "macOS is up to date"
                                  : "\(found.count) macOS update\(found.count == 1 ? "" : "s") available")
        }
    }
}
