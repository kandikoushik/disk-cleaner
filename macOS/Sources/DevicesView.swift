import SwiftUI

struct DevicesView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var watcher = DeviceWatcher()
    @State private var busy: String?
    @State private var scanned: [String: [FolderEntry]] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { watcher.refresh() } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Spacer()
                Text("Plug something in and it appears here automatically")
                    .font(.system(size: 11)).foregroundStyle(Color.inkTertiary)
            }

            if watcher.devices.isEmpty {
                emptyState
            } else {
                ForEach(watcher.devices) { device in
                    card(device)
                }
            }
        }
        .onAppear { watcher.start { _ in } }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cable.connector")
                .font(.system(size: 26)).foregroundStyle(Color.inkTertiary)
            Text("Nothing connected")
                .font(.system(size: 13, weight: .medium))
            Text("Connect a drive, iPhone or Android phone and it shows up here.")
                .font(.system(size: 11.5)).foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 44)
    }

    // ------------------------------------------------------------------

    private func card(_ d: ConnectedDevice) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 12) {
                Image(systemName: d.kind.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brand)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(d.name).font(.system(size: 14, weight: .semibold))
                    Text(d.detail).font(.system(size: 11.5))
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer(minLength: 8)

                if busy == d.id { ProgressView().controlSize(.small) }
            }

            if d.hasCapacity {
                VStack(alignment: .leading, spacing: 4) {
                    MiniBar(fraction: Double(d.used) / Double(max(d.total, 1)))
                    HStack {
                        Text("\(fmtBytes(d.free)) free").font(.system(size: 10.5))
                            .foregroundStyle(Color.inkSecondary)
                        Spacer()
                        Text("\(fmtBytes(d.total)) capacity").font(.system(size: 10.5))
                            .foregroundStyle(Color.inkTertiary)
                    }
                }
            }

            actions(for: d)

            if let folders = scanned[d.id], !folders.isEmpty {
                Divider().opacity(0.5)
                Text("Biggest folders on this device")
                    .font(.system(size: 11, weight: .semibold))
                ForEach(folders.prefix(8)) { f in
                    HStack(spacing: 9) {
                        MiniBar(fraction: Double(f.size) / Double(max(folders[0].size, 1)))
                            .frame(width: 54)
                        Text(f.name).font(.system(size: 11.5)).lineLimit(1)
                        Spacer(minLength: 6)
                        Text(fmtBytes(f.size))
                            .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(Color.inkSecondary)
                        Button { Explore.reveal(f.path) } label: {
                            Image(systemName: "magnifyingglass").font(.system(size: 10))
                        }.buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(14)
        .glassSurface(radius: 13)
        .padding(.bottom, 9)
    }

    @ViewBuilder
    private func actions(for d: ConnectedDevice) -> some View {
        HStack(spacing: 8) {
            switch d.kind {
            case .volume:
                Button("Scan this device") { scanVolume(d) }
                    .disabled(busy != nil)
                Button("Reveal") { Explore.reveal(d.path ?? "") }
                if d.removable {
                    Button("Eject") {
                        if Devices.eject(d.path ?? "") {
                            app.say("Ejected \(d.name)"); watcher.refresh()
                        } else { app.say("Could not eject — something is still using it") }
                    }
                }

            case .android:
                Button("Copy photos to Mac") { backupAndroid(d) }
                    .disabled(busy != nil || !d.detail.contains("ready"))
                Button("Storage") {
                    let serial = d.id.replacingOccurrences(of: "android-", with: "")
                    app.say(Devices.androidStorage(serial: serial) ?? "Could not read storage")
                }

            case .iphone:
                Button("Import photos") { Devices.openImageCapture() }
                Button("Open in Finder") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))
                }
            }
            Spacer()
        }
        .controlSize(.small)

        // Say plainly what each platform allows, rather than implying a full
        // clone is possible everywhere.
        if d.kind == .iphone {
            Text("Apple does not allow apps to read an iPhone's filesystem directly, "
                 + "so a full clone is not possible from here. Image Capture and Finder "
                 + "are the sanctioned routes for photos and backups.")
                .font(.system(size: 10.5)).foregroundStyle(Color.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        } else if d.kind == .android && !d.detail.contains("ready") {
            Text("Unlock the phone and allow USB debugging to enable copying.")
                .font(.system(size: 10.5)).foregroundStyle(Color.riskRebuild)
        }
    }

    // ------------------------------------------------------------------

    private func scanVolume(_ d: ConnectedDevice) {
        guard let root = d.path else { return }
        busy = d.id
        Task {
            let found = await Task.detached(priority: .userInitiated) { () -> [FolderEntry] in
                let fm = FileManager.default
                guard let kids = try? fm.contentsOfDirectory(atPath: root) else { return [] }
                var out: [FolderEntry] = []
                for k in kids where !k.hasPrefix(".") {
                    let p = (root as NSString).appendingPathComponent(k)
                    out.append(FolderEntry(path: p, name: k, parent: d.name,
                                           size: Sizer.walk(p)))
                }
                return out.sorted { $0.size > $1.size }
            }.value
            scanned[d.id] = found
            busy = nil
            app.say(found.isEmpty ? "Nothing to measure on \(d.name)"
                                  : "Scanned \(d.name) — \(found.count) folders")
        }
    }

    private func backupAndroid(_ d: ConnectedDevice) {
        let serial = d.id.replacingOccurrences(of: "android-", with: "")
        let dest = "\(HOME)/Pictures/\(d.name.replacingOccurrences(of: " ", with: "-"))-backup"
        busy = d.id
        Task {
            let message = await Task.detached(priority: .userInitiated) {
                Devices.backupAndroidMedia(serial: serial, to: dest)
            }.value
            busy = nil
            app.say(message)
        }
    }
}
