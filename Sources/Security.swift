import Foundation

// ---------------------------------------------------------------------------
// Security posture
//
// This is deliberately NOT an antivirus. Signature-based malware scanning needs
// a maintained, frequently-updated definition database; shipping a stale one
// would give false confidence, which is worse than offering nothing.
//
// What this does instead is auditable with facts already on the machine:
//   - is macOS's own protection (XProtect, Gatekeeper, SIP, FileVault) healthy
//   - which installed apps are unsigned, ad-hoc signed, or not notarised
//   - which launch agents persist from paths malware actually favours
//
// Every finding names the evidence, so nothing here asks to be believed.
// ---------------------------------------------------------------------------

enum Severity: String {
    case ok, info, warn, serious

    var order: Int {
        switch self {
        case .serious: return 0
        case .warn: return 1
        case .info: return 2
        case .ok: return 3
        }
    }
}

struct SecurityFinding: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let severity: Severity
    var path: String? = nil
}

enum Security {

    // ---- macOS's own defences ----------------------------------------------

    static func systemChecks() -> [SecurityFinding] {
        var out: [SecurityFinding] = []

        // XProtect — Apple's built-in malware definitions.
        let xprotectPlist = "/Library/Apple/System/Library/CoreServices/"
            + "XProtect.bundle/Contents/Info.plist"
        if let d = NSDictionary(contentsOfFile: xprotectPlist),
           let version = d["CFBundleShortVersionString"] as? String {
            var age = ""
            var severity = Severity.ok
            if let attrs = try? FileManager.default.attributesOfItem(atPath: xprotectPlist),
               let modified = attrs[.modificationDate] as? Date {
                let days = Int(Date().timeIntervalSince(modified) / 86400)
                age = " · updated \(days) day\(days == 1 ? "" : "s") ago"
                // Apple ships XProtect updates often; a long gap means the
                // machine is not receiving background security updates.
                if days > 60 { severity = .warn }
            }
            out.append(SecurityFinding(
                id: "xprotect",
                title: severity == .ok ? "XProtect is current" : "XProtect looks stale",
                detail: "Apple's built-in malware definitions, version \(version)\(age).",
                severity: severity))
        } else {
            out.append(SecurityFinding(id: "xprotect", title: "XProtect not readable",
                                       detail: "Could not read Apple's malware definitions.",
                                       severity: .info))
        }

        // Gatekeeper
        let gk = Shell.run("/usr/sbin/spctl", ["--status"]) ?? ""
        let gkOn = gk.contains("enabled")
        out.append(SecurityFinding(
            id: "gatekeeper",
            title: gkOn ? "Gatekeeper is on" : "Gatekeeper is OFF",
            detail: gkOn ? "Unsigned and unnotarised apps are blocked by default."
                         : "Apps from anywhere can launch without checks. Re-enable with "
                           + "`sudo spctl --master-enable`.",
            severity: gkOn ? .ok : .serious))

        // System Integrity Protection
        let sip = Shell.run("/usr/bin/csrutil", ["status"]) ?? ""
        let sipOn = sip.lowercased().contains("enabled")
        out.append(SecurityFinding(
            id: "sip",
            title: sipOn ? "System Integrity Protection is on" : "SIP is DISABLED",
            detail: sipOn ? "Protected system locations cannot be modified, even by root."
                          : "System files can be modified by root. Re-enable from Recovery.",
            severity: sipOn ? .ok : .serious))

        // FileVault
        let fv = Shell.run("/usr/bin/fdesetup", ["status"]) ?? ""
        let fvOn = fv.contains("FileVault is On")
        out.append(SecurityFinding(
            id: "filevault",
            title: fvOn ? "FileVault is on" : "FileVault is off",
            detail: fvOn ? "The disk is encrypted at rest."
                         : "Disk contents are readable if the Mac is lost or stolen.",
            severity: fvOn ? .ok : .warn))

        // Application firewall
        let fw = Shell.run("/usr/bin/defaults",
                           ["read", "/Library/Preferences/com.apple.alf", "globalstate"]) ?? "0"
        let fwOn = (Int(fw.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) > 0
        out.append(SecurityFinding(
            id: "firewall",
            title: fwOn ? "Firewall is on" : "Firewall is off",
            detail: fwOn ? "Incoming connections are filtered."
                         : "Incoming connections are unfiltered. Anything listening on a "
                           + "reachable port is exposed on your network.",
            severity: fwOn ? .ok : .warn))

        return out.sorted { $0.severity.order < $1.severity.order }
    }

    // ---- persistence audit --------------------------------------------------

    /// Directories malware favours for persistence, because they are writable
    /// without admin rights and are not where legitimate software lives.
    private static let suspiciousRoots = [
        "/tmp/", "/private/tmp/", "/Users/Shared/", "/var/tmp/",
    ]

    /// Launch agents whose program lives somewhere questionable, or which have
    /// no readable program at all.
    static func persistenceFindings() -> [SecurityFinding] {
        var out: [SecurityFinding] = []
        for item in Startup.items() {
            let prog = item.program
            guard prog != "—" else { continue }

            var reason: String? = nil
            if suspiciousRoots.contains(where: { prog.hasPrefix($0) }) {
                reason = "Runs from a temporary or shared directory, which is where "
                       + "persistent malware usually hides."
            } else if prog.contains("/.") && !prog.hasPrefix("/System") {
                reason = "Runs from a hidden path."
            } else if !FileManager.default.fileExists(atPath: prog)
                        && prog.hasPrefix("/") {
                reason = "Points at a program that no longer exists — a leftover agent."
            }

            if let reason {
                out.append(SecurityFinding(
                    id: "persist-\(item.path)",
                    title: item.label,
                    detail: "\(reason)\n\(prog)",
                    severity: reason.hasPrefix("Points at") ? .warn : .serious,
                    path: item.path))
            }
        }
        return out.sorted { $0.severity.order < $1.severity.order }
    }

    // ---- code signing audit -------------------------------------------------

    /// Apps that are unsigned, ad-hoc signed, or not notarised. Note that a
    /// locally-built app (including this one) will legitimately show here.
    static func unsignedApps(limit: Int = 40) async -> [SecurityFinding] {
        let roots = ["/Applications", "\(HOME)/Applications"]
        let fm = FileManager.default
        var apps: [String] = []
        for root in roots {
            guard let kids = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for k in kids where k.hasSuffix(".app") {
                apps.append((root as NSString).appendingPathComponent(k))
            }
        }

        return await withTaskGroup(of: SecurityFinding?.self) { group in
            for path in apps.prefix(limit) {
                group.addTask {
                    let assess = Shell.run("/usr/sbin/spctl",
                                           ["--assess", "--type", "execute", path],
                                           timeout: 20) ?? ""
                    // spctl writes its verdict to stderr; an empty result with a
                    // successful signature check is the accepted case.
                    let sig = Shell.run("/usr/bin/codesign",
                                        ["-dv", "--verbose=2", path], timeout: 20) ?? ""
                    let name = ((path as NSString).lastPathComponent as NSString)
                        .deletingPathExtension

                    if sig.isEmpty {
                        return SecurityFinding(
                            id: "sign-\(path)", title: name,
                            detail: "No code signature at all.", severity: .warn, path: path)
                    }
                    if sig.contains("Signature=adhoc") {
                        return SecurityFinding(
                            id: "sign-\(path)", title: name,
                            detail: "Ad-hoc signed — no verifiable developer identity.",
                            severity: .warn, path: path)
                    }
                    if assess.contains("rejected") {
                        return SecurityFinding(
                            id: "sign-\(path)", title: name,
                            detail: "Signed, but not notarised by Apple. Expected for "
                                  + "locally-built apps; unexpected for downloaded ones.",
                            severity: .info, path: path)
                    }
                    return nil
                }
            }
            var out: [SecurityFinding] = []
            for await f in group { if let f { out.append(f) } }
            return out.sorted { $0.severity.order < $1.severity.order }
        }
    }
}
