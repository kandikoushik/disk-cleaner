import Foundation
import AppKit

// ---------------------------------------------------------------------------
// Connected devices
//
// Three kinds, detected three ways:
//   volumes  — FileManager, native and instant
//   iPhone   — `xcrun devicectl list devices` (Xcode's own device service)
//   Android  — `adb devices -l` from the Android SDK, when it is installed
//
// On "clone": what is honestly possible differs sharply per device.
//   External volume — a real copy is possible and offered.
//   Android         — media pull over adb is possible and offered.
//   iPhone          — Apple does not permit arbitrary filesystem access from a
//                     normal app. We hand off to Finder/Image Capture rather
//                     than pretending to clone it. See `DeviceAction.note`.
// ---------------------------------------------------------------------------

enum DeviceKind: String {
    case volume, iphone, android

    var icon: String {
        switch self {
        case .volume:  return "externaldrive.fill"
        case .iphone:  return "iphone"
        case .android: return "candybarphone"
        }
    }
}

struct ConnectedDevice: Identifiable, Hashable {
    let id: String
    let kind: DeviceKind
    let name: String
    let detail: String
    var path: String? = nil          // volumes only
    var total: Int64 = 0
    var free: Int64 = 0
    var removable = false

    var used: Int64 { max(0, total - free) }
    var hasCapacity: Bool { total > 0 }
}

enum Devices {

    // ---- external volumes ---------------------------------------------------

    static func volumes() -> [ConnectedDevice] {
        let keys: [URLResourceKey] = [
            .volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey,
            .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
            .volumeIsInternalKey, .volumeIsBrowsableKey,
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes])
        else { return [] }

        var out: [ConnectedDevice] = []
        for url in urls {
            guard let v = try? url.resourceValues(forKeys: Set(keys)),
                  v.volumeIsBrowsable == true else { continue }
            // The boot volume is the app's whole subject already; only show the
            // things a user thinks of as "a device I plugged in".
            let internalVolume = v.volumeIsInternal ?? false
            let removable = (v.volumeIsRemovable ?? false) || (v.volumeIsEjectable ?? false)
            guard !internalVolume || removable else { continue }

            let name = v.volumeName ?? url.lastPathComponent
            let total = Int64(v.volumeTotalCapacity ?? 0)
            let free = Int64(v.volumeAvailableCapacity ?? 0)
            out.append(ConnectedDevice(
                id: url.path, kind: .volume, name: name,
                detail: total > 0 ? "\(fmtBytes(total - free)) used of \(fmtBytes(total))"
                                  : url.path,
                path: url.path, total: total, free: free, removable: removable))
        }
        return out.sorted { $0.name < $1.name }
    }

    // ---- iPhone / iPad ------------------------------------------------------

    static func appleDevices() -> [ConnectedDevice] {
        guard let out = Shell.run("/usr/bin/xcrun", ["devicectl", "list", "devices"],
                                  timeout: 25)
        else { return [] }
        var found: [ConnectedDevice] = []
        for line in out.split(separator: "\n").dropFirst() {
            let text = String(line)
            guard text.contains("iPhone") || text.contains("iPad") else { continue }
            let cols = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard let name = cols.first else { continue }
            // Model is the tail of the row, e.g. "iPhone 15 Pro (iPhone16,1)".
            let model = text.range(of: "iPhone").map { String(text[$0.lowerBound...]) }
                ?? "Apple device"
            let paired = text.contains("paired")
            found.append(ConnectedDevice(
                id: "ios-\(name)", kind: .iphone, name: name,
                detail: model.trimmingCharacters(in: .whitespaces)
                    + (paired ? " · paired" : " · not paired")))
        }
        return found
    }

    // ---- Android ------------------------------------------------------------

    static var adbPath: String? {
        let candidates = [
            "\(HOME)/Library/Android/sdk/platform-tools/adb",
            "/opt/homebrew/bin/adb", "/usr/local/bin/adb",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func androidDevices() -> [ConnectedDevice] {
        guard let adb = adbPath,
              let out = Shell.run(adb, ["devices", "-l"], timeout: 20) else { return [] }
        var found: [ConnectedDevice] = []
        for line in out.split(separator: "\n").dropFirst() {
            let text = String(line).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, !text.hasPrefix("*") else { continue }
            let cols = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard cols.count >= 2 else { continue }
            let serial = cols[0]
            let state = cols[1]
            let model = cols.first { $0.hasPrefix("model:") }?
                .replacingOccurrences(of: "model:", with: "")
                .replacingOccurrences(of: "_", with: " ") ?? "Android device"
            let detail: String
            switch state {
            case "device":       detail = "\(model) · ready"
            case "unauthorized": detail = "\(model) · unlock the phone and allow USB debugging"
            case "offline":      detail = "\(model) · offline"
            default:             detail = "\(model) · \(state)"
            }
            found.append(ConnectedDevice(id: "android-\(serial)", kind: .android,
                                         name: model, detail: detail))
        }
        return found
    }

    static func all() -> [ConnectedDevice] {
        volumes() + appleDevices() + androidDevices()
    }

    // ---- actions ------------------------------------------------------------

    /// Copy a device's photos and videos somewhere on this Mac.
    ///
    /// Android only: adb can read shared storage. iOS cannot be read this way,
    /// which is why the iPhone offer is a hand-off instead.
    static func backupAndroidMedia(serial: String, to destination: String) -> String {
        guard let adb = adbPath else { return "adb not found" }
        try? FileManager.default.createDirectory(atPath: destination,
                                                 withIntermediateDirectories: true)
        let out = Shell.run(adb, ["-s", serial, "pull", "/sdcard/DCIM", destination],
                            timeout: 3600)
        return out?.contains("error") == false
            ? "Photos copied to \(tilde(destination))"
            : "Copy failed — check the phone is unlocked and USB debugging is allowed"
    }

    /// Free space on an Android device.
    static func androidStorage(serial: String) -> String? {
        guard let adb = adbPath,
              let out = Shell.run(adb, ["-s", serial, "shell", "df", "-h", "/sdcard"],
                                  timeout: 20) else { return nil }
        let lines = out.split(separator: "\n")
        guard lines.count > 1 else { return nil }
        let f = lines[1].split(separator: " ", omittingEmptySubsequences: true)
        guard f.count >= 4 else { return nil }
        return "\(f[2]) used of \(f[1]) · \(f[3]) free"
    }

    /// iPhone/iPad hand-off. Apple gates device filesystem access, so the honest
    /// move is to open the tool that is allowed to do it.
    static func openImageCapture() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Image Capture.app"))
    }

    static func eject(_ path: String) -> Bool {
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: URL(fileURLWithPath: path))
            return true
        } catch {
            return false
        }
    }
}

// ---------------------------------------------------------------------------
// Mount watching — so plugging something in offers to scan it, rather than
// waiting to be discovered.
// ---------------------------------------------------------------------------

@MainActor
final class DeviceWatcher: ObservableObject {
    @Published var devices: [ConnectedDevice] = []
    @Published var lastAttached: ConnectedDevice?

    private var observers: [NSObjectProtocol] = []

    func start(onAttach: @escaping (ConnectedDevice) -> Void) {
        refresh()
        let nc = NSWorkspace.shared.notificationCenter
        for note in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            observers.append(nc.addObserver(forName: note, object: nil, queue: .main) { [weak self] n in
                guard let self else { return }
                let before = Set(self.devices.map(\.id))
                self.refresh()
                if note == NSWorkspace.didMountNotification,
                   let fresh = self.devices.first(where: { !before.contains($0.id) }) {
                    self.lastAttached = fresh
                    onAttach(fresh)
                }
            })
        }
    }

    func refresh() {
        // Volumes are instant; the two shell probes are not, so they run off-main.
        devices = Devices.volumes()
        Task.detached(priority: .utility) {
            let phones = Devices.appleDevices() + Devices.androidDevices()
            await MainActor.run {
                let vols = self.devices.filter { $0.kind == .volume }
                self.devices = vols + phones
            }
        }
    }

    deinit {
        let nc = NSWorkspace.shared.notificationCenter
        observers.forEach { nc.removeObserver($0) }
    }
}
