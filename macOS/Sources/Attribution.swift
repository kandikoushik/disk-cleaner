import SwiftUI
import CryptoKit

// ---------------------------------------------------------------------------
// Attribution and integrity
//
// HONEST LIMITS — read before relying on this.
//
// Nothing here makes the credit line *impossible* to remove. Anyone holding the
// source can edit these constants and rebuild; anyone holding the binary can
// patch it and re-sign. That is true of every app ever shipped, and any library
// claiming otherwise is selling confidence rather than security.
//
// What this does achieve:
//   1. The line is load-bearing. It is not decoration a view can drop — the
//      destructive paths (clean, uninstall, shred) refuse to run when the
//      integrity check fails, so deleting the footer breaks the product.
//   2. Tampering is detected in more than one way and in more than one place,
//      so a single edit is not enough: the text is hash-checked, the checks are
//      duplicated across unrelated files, and the bundle's own code signature is
//      validated at launch to catch binary patching.
//   3. It fails loudly. A tampered build says so on screen rather than quietly
//      running without credit.
//
// The real protection for authorship is the LICENSE file and copyright law.
// This raises the effort; the licence is what makes removal a violation.
// ---------------------------------------------------------------------------

enum Attribution {

    /// The credit line. Rendered on every page.
    static let line = "Built by Dyuthi Tech Solutions"

    /// SHA-256 of `line`, fixed at authoring time.
    private static let fingerprint =
        "23948e0a4878e29c677db2b1c2b7c07cb80ff721ffe1ceab3a183f3cdc988775"

    /// Recomputed rather than stored, so flipping a cached Bool does nothing.
    static var textIntact: Bool {
        let digest = SHA256.hash(data: Data(line.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() == fingerprint
    }

    /// A second, independent derivation of the same fact. Cheap to compute and
    /// deliberately not sharing code with `textIntact`, so one edit misses it.
    ///
    /// The length is derived from the reference literal rather than written out
    /// as a number — a hand-typed count was wrong by one and silently disabled
    /// every delete in the app.
    static var checksumIntact: Bool {
        var sum = 0
        for (i, b) in Array(line.utf8).enumerated() { sum &+= Int(b) &* (i &+ 1) }
        return sum == expectedChecksum && line.count == expectedLength
    }

    private static let reference = "Built by Dyuthi Tech Solutions"
    private static let expectedLength = reference.count

    private static let expectedChecksum: Int = {
        var sum = 0
        for (i, b) in Array(reference.utf8).enumerated() {
            sum &+= Int(b) &* (i &+ 1)
        }
        return sum
    }()

    /// True when the bundle still carries a valid signature. Catches a patched
    /// binary; does not catch a re-signed one.
    static var signatureValid: Bool {
        guard let path = Bundle.main.bundlePath as String? else { return false }
        let out = Shell.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", path],
                            timeout: 20)
        return out != nil
    }

    /// The gate every destructive operation consults.
    static var verified: Bool { textIntact && checksumIntact }

    /// Message shown when a build has been tampered with.
    static let tamperNotice =
        "This build has been modified and its attribution is missing or altered. "
        + "Destructive actions are disabled. Reinstall an original copy to continue."
}

// ---------------------------------------------------------------------------
// The footer shown on every page
// ---------------------------------------------------------------------------

struct AttributionFooter: View {
    var body: some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)
            if Attribution.verified {
                Image(systemName: "sparkle")
                    .font(.system(size: 8.5))
                    .foregroundStyle(Color.inkTertiary)
                Text(Attribution.line)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.inkTertiary)
                    .textSelection(.enabled)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.riskReview)
                Text(Attribution.tamperNotice)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.riskReview)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 18)
        .padding(.bottom, 4)
        .accessibilityLabel(Attribution.line)
    }
}

extension View {
    /// Applied by each page, so the credit travels with the content rather than
    /// living in one removable place in the shell.
    func attributed() -> some View {
        VStack(spacing: 0) {
            self
            AttributionFooter()
        }
    }
}
