import Foundation
import AppKit
import IOKit.ps

// ---------------------------------------------------------------------------
// Machine, OS, accounts and pending updates.
//
// Everything here is read-only. The serial number is deliberately masked in the
// UI — it identifies the machine to Apple and to warranty lookups, and there is
// no reason for a screen-share or screenshot to leak it.
// ---------------------------------------------------------------------------

struct InfoRow: Identifiable, Hashable {
    let label: String
    let value: String
    var sensitive = false
    var id: String { label }
}

struct SoftwareUpdate: Identifiable, Hashable {
    let name: String
    let version: String
    let size: String
    let recommended: Bool
    var id: String { name }
}

struct LoggedInUser: Identifiable, Hashable {
    let name: String
    let terminal: String
    let since: String
    let isCurrent: Bool
    let isAdmin: Bool
    var id: String { name + terminal }
}

enum SystemInfo {

    // ---- hardware -----------------------------------------------------------

    static func hardware() -> [InfoRow] {
        var rows: [InfoRow] = []
        let raw = Shell.run("/usr/sbin/system_profiler", ["SPHardwareDataType"], timeout: 30) ?? ""

        func field(_ key: String) -> String? {
            for line in raw.split(separator: "\n") where line.contains(key) {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    return parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
            return nil
        }

        if let v = field("Model Name")       { rows.append(InfoRow(label: "Model", value: v)) }
        if let v = field("Model Identifier") { rows.append(InfoRow(label: "Identifier", value: v)) }
        if let v = field("Chip")             { rows.append(InfoRow(label: "Chip", value: v)) }
        if let v = field("Total Number of Cores") {
            rows.append(InfoRow(label: "Cores", value: v))
        }
        if let v = field("Memory")           { rows.append(InfoRow(label: "Memory", value: v)) }
        if let v = field("Serial Number (system)") {
            rows.append(InfoRow(label: "Serial", value: v, sensitive: true))
        }

        let disk = DiskStats.current()
        rows.append(InfoRow(label: "Storage",
                            value: "\(fmtBytes(disk.free)) free of \(fmtBytes(disk.total))"))
        return rows
    }

    // ---- operating system ---------------------------------------------------

    static func operatingSystem() -> [InfoRow] {
        var rows: [InfoRow] = []
        let v = ProcessInfo.processInfo.operatingSystemVersion
        rows.append(InfoRow(label: "macOS", value: "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"))
        if let build = Shell.run("/usr/bin/sw_vers", ["-buildVersion"])?
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            rows.append(InfoRow(label: "Build", value: build))
        }
        rows.append(InfoRow(label: "Kernel", value: ProcessInfo.processInfo.operatingSystemVersionString
            .replacingOccurrences(of: "Version ", with: "")))

        let up = ProcessInfo.processInfo.systemUptime
        let days = Int(up) / 86400, hours = (Int(up) % 86400) / 3600
        rows.append(InfoRow(label: "Uptime",
                            value: days > 0 ? "\(days)d \(hours)h" : "\(hours)h"))
        rows.append(InfoRow(label: "Hostname", value: ProcessInfo.processInfo.hostName))

        // Power source: a Mac mini has no battery, so this reads "AC power"
        // rather than inventing a percentage.
        rows.append(InfoRow(label: "Power", value: powerSource()))
        return rows
    }

    private static func powerSource() -> String {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty
        else { return "AC power (no battery)" }

        for source in sources {
            guard let d = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            let current = d[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = d[kIOPSMaxCapacityKey] as? Int ?? 100
            let charging = d[kIOPSIsChargingKey] as? Bool ?? false
            let pct = max > 0 ? current * 100 / max : 0
            return "\(pct)% \(charging ? "charging" : "on battery")"
        }
        return "AC power (no battery)"
    }

    // ---- accounts -----------------------------------------------------------

    static func users() -> [LoggedInUser] {
        let me = NSUserName()
        let admins = Set((Shell.run("/usr/bin/dscl", [".", "-read", "/Groups/admin",
                                                      "GroupMembership"]) ?? "")
            .replacingOccurrences(of: "GroupMembership:", with: "")
            .split(separator: " ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })

        var out: [LoggedInUser] = []
        for line in (Shell.run("/usr/bin/who", []) ?? "").split(separator: "\n") {
            let f = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard f.count >= 3 else { continue }
            let name = f[0]
            let since = f.dropFirst(2).joined(separator: " ")
            out.append(LoggedInUser(name: name, terminal: f[1], since: since,
                                    isCurrent: name == me, isAdmin: admins.contains(name)))
        }
        return out
    }

    /// A full account profile, including the picture macOS stores for it.
    struct Profile: Identifiable, Hashable {
        let shortName: String
        let fullName: String
        let isAdmin: Bool
        let home: String
        let shell: String
        let uid: String
        let avatar: Data?
        var id: String { shortName }
    }

    private static func dscl(_ user: String, _ key: String) -> String? {
        guard let out = Shell.run("/usr/bin/dscl", [".", "-read", "/Users/\(user)", key],
                                  timeout: 15) else { return nil }
        // Single-line form is "Key: value"; multi-line puts the value beneath.
        if let r = out.range(of: "\(key):") {
            let rest = out[r.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return rest.isEmpty ? nil : rest
        }
        return nil
    }

    /// The account picture. `JPEGPhoto` holds the real bytes when the user has
    /// set one; `Picture` is only a path to a stock image, so it is the
    /// fallback rather than the primary source.
    static func avatar(for user: String) -> Data? {
        if let raw = Shell.run("/usr/bin/dscl", [".", "-read", "/Users/\(user)", "JPEGPhoto"]) {
            let hex = raw.replacingOccurrences(of: "JPEGPhoto:", with: "")
                         .filter { $0.isHexDigit }
            var bytes = [UInt8]()
            bytes.reserveCapacity(hex.count / 2)
            var index = hex.startIndex
            while index < hex.endIndex {
                let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
                if index < nextIndex, let byte = UInt8(hex[index..<nextIndex], radix: 16) {
                    bytes.append(byte)
                }
                index = nextIndex
            }
            if bytes.count > 100 { return Data(bytes) }
        }
        if let path = dscl(user, "Picture")?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")),
           FileManager.default.fileExists(atPath: path) {
            return FileManager.default.contents(atPath: path)
        }
        return nil
    }

    static func profiles() -> [Profile] {
        let admins = Set((Shell.run("/usr/bin/dscl", [".", "-read", "/Groups/admin",
                                                      "GroupMembership"]) ?? "")
            .replacingOccurrences(of: "GroupMembership:", with: "")
            .split(separator: " ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })

        let names = (Shell.run("/usr/bin/dscl", [".", "list", "/Users"]) ?? "")
            .split(separator: "\n").map(String.init)
            .filter { !$0.hasPrefix("_") && !["daemon", "nobody", "root"].contains($0) }

        return names.map { name in
            Profile(shortName: name,
                    fullName: dscl(name, "RealName") ?? name,
                    isAdmin: admins.contains(name),
                    home: dscl(name, "NFSHomeDirectory") ?? "—",
                    shell: dscl(name, "UserShell") ?? "—",
                    uid: dscl(name, "UniqueID") ?? "—",
                    avatar: avatar(for: name))
        }
    }

    // ---- software updates ---------------------------------------------------

    /// `softwareupdate -l` talks to Apple, so this is slow — always call it off
    /// the main thread.
    static func pendingUpdates() -> [SoftwareUpdate] {
        guard let out = Shell.run("/usr/sbin/softwareupdate", ["-l"], timeout: 180)
        else { return [] }

        var updates: [SoftwareUpdate] = []
        var pendingLabel: String?
        for raw in out.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("* Label:") {
                pendingLabel = line.replacingOccurrences(of: "* Label:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if let label = pendingLabel, line.contains("Title:") {
                func part(_ key: String) -> String {
                    guard let r = line.range(of: "\(key):") else { return "" }
                    let rest = line[r.upperBound...]
                    let value = rest.split(separator: ",").first.map(String.init) ?? ""
                    return value.trimmingCharacters(in: .whitespaces)
                }
                updates.append(SoftwareUpdate(
                    name: part("Title").isEmpty ? label : part("Title"),
                    version: part("Version"),
                    size: part("Size").isEmpty ? "" : part("Size") + " KiB",
                    recommended: line.contains("Recommended: YES")))
                pendingLabel = nil
            }
        }
        return updates
    }

    static func openSoftwareUpdatePane() {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preferences.softwareupdate")!)
    }
}
