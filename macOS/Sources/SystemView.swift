import SwiftUI

struct SystemView: View {
    @EnvironmentObject var app: AppState

    // Held locally rather than in AppState: nothing else in the app needs these,
    // and it keeps the shared state object from growing for one page.
    @State private var hardware: [InfoRow] = []
    @State private var os: [InfoRow] = []
    @State private var signedIn: [LoggedInUser] = []
    @State private var accounts: [InfoRow] = []
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

            SectionHeader(title: "Signed in now", trailing: "\(signedIn.count)")
            ForEach(signedIn) { u in userRow(u) }

            SectionHeader(title: "All accounts", trailing: "\(accounts.count)")
            ForEach(accounts) { a in
                HStack {
                    Image(systemName: a.value == "Administrator"
                          ? "person.badge.key.fill" : "person.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(a.value == "Administrator" ? Color.brand : Color.inkTertiary)
                        .frame(width: 18)
                    Text(a.label).font(.system(size: 12.5))
                    Spacer()
                    Text(a.value).font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.inkSecondary)
                }
                .padding(.horizontal, 13).padding(.vertical, 8)
                .glassSurface(radius: 10)
                .padding(.bottom, 5)
            }
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

    private func userRow(_ u: LoggedInUser) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 18)).foregroundStyle(Color.brand)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(u.name).font(.system(size: 13, weight: .semibold))
                    if u.isCurrent {
                        Text("YOU").font(.system(size: 8.5, weight: .bold)).tracking(0.5)
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(Color.brand.opacity(0.16),
                                        in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(Color.brand)
                    }
                    if u.isAdmin {
                        Text("ADMIN").font(.system(size: 8.5, weight: .bold)).tracking(0.5)
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(Color.riskRebuild.opacity(0.16),
                                        in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(Color.riskRebuild)
                    }
                }
                Text("\(u.terminal) · since \(u.since)")
                    .font(.system(size: 11)).foregroundStyle(Color.inkSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 13).padding(.vertical, 9)
        .glassSurface(radius: 11)
        .padding(.bottom, 6)
    }

    // ------------------------------------------------------------------

    private func load() {
        loading = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                (SystemInfo.hardware(), SystemInfo.operatingSystem(),
                 SystemInfo.users(), SystemInfo.allAccounts())
            }.value
            hardware = result.0
            os = result.1
            signedIn = result.2
            accounts = result.3
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
