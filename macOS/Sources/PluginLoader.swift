import Foundation

// ---------------------------------------------------------------------------
// Dynamic Plugin Target Loader
// Scans ~/.config/disk-cleaner/plugins/*.json for custom user rules.
// ---------------------------------------------------------------------------

struct CustomPluginRule: Codable {
    let id: String
    let label: String
    let note: String
    let risk: String // "safe", "rebuild", "review"
    let category: String
    let paths: [String]
}

enum PluginLoader {
    static func loadCustomTargets() -> [Target] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pluginDir = "\(home)/.config/disk-cleaner/plugins"
        
        let fm = FileManager.default
        guard fm.fileExists(atPath: pluginDir) else { return [] }
        
        guard let files = try? fm.contentsOfDirectory(atPath: pluginDir) else { return [] }
        var loaded: [Target] = []
        
        for file in files where file.hasSuffix(".json") {
            let fullPath = "\(pluginDir)/\(file)"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)) else { continue }
            guard let rules = try? JSONDecoder().decode([CustomPluginRule].self, from: data) else { continue }
            
            for r in rules {
                let riskType: Risk = {
                    switch r.risk.lowercased() {
                    case "safe": return .safe
                    case "rebuild": return .rebuild
                    default: return .review
                    }
                }()
                
                let expandedPaths = r.paths.map { $0.replacingOccurrences(of: "~", with: home) }
                let t = Target(
                    id: "custom_\(r.id)",
                    label: "🔌 \(r.label)",
                    note: r.note,
                    risk: riskType,
                    category: .apps,
                    source: .paths(expandedPaths)
                )
                loaded.append(t)
            }
        }
        
        return loaded
    }
}
