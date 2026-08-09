import Foundation

// ---------------------------------------------------------------------------
// What the app knows how to clean.
//
// risk .safe    = pure cache, regenerates silently
//      .rebuild = regenerates, but costs a re-download or a rebuild
//      .review  = your data; never auto-selected, inspect before deleting
// ---------------------------------------------------------------------------

enum Catalog {
    static let targets: [Target] = [

        // ---- Xcode ----
        Target(id: "xcode_derived", label: "Xcode DerivedData",
               note: "Build intermediates. Xcode regenerates on next build.",
               risk: .safe, category: .xcode,
               source: .paths(["\(HOME)/Library/Developer/Xcode/DerivedData/*"])),

        Target(id: "xcode_devsupport", label: "Xcode Device Support",
               note: "Symbol caches. Re-created when you next plug in a device.",
               risk: .safe, category: .xcode,
               source: .paths(["\(HOME)/Library/Developer/Xcode/iOS DeviceSupport/*",
                               "\(HOME)/Library/Developer/Xcode/watchOS DeviceSupport/*",
                               "\(HOME)/Library/Developer/Xcode/tvOS DeviceSupport/*"])),

        Target(id: "xcode_archives", label: "Xcode Archives",
               note: "Shipped-build archives. Needed to re-symbolicate old crash logs.",
               risk: .review, category: .xcode,
               source: .paths(["\(HOME)/Library/Developer/Xcode/Archives/*"])),

        Target(id: "swiftpm", label: "SwiftPM cache",
               note: "Swift package clones. Re-resolved on next build.",
               risk: .safe, category: .xcode,
               source: .paths(["\(HOME)/Library/Caches/org.swift.swiftpm"])),

        // ---- Simulators ----
        Target(id: "sim_unavailable", label: "Unavailable simulators",
               note: "Devices whose runtime is no longer installed.",
               risk: .safe, category: .simulators,
               source: .dynamic(.unavailableSimulators)),

        Target(id: "sim_all", label: "ALL simulator devices",
               note: "Erases every simulator and its installed apps. Re-creatable.",
               risk: .rebuild, category: .simulators,
               source: .command("xcrun simctl delete all",
                                measured: ["\(HOME)/Library/Developer/CoreSimulator/Devices"])),

        // ---- Android ----
        Target(id: "gradle", label: "Gradle caches & daemons",
               note: "Android build cache. Re-downloads dependencies on next build.",
               risk: .safe, category: .android,
               source: .paths(["\(HOME)/.gradle/caches", "\(HOME)/.gradle/daemon",
                               "\(HOME)/.gradle/wrapper/dists"])),

        Target(id: "ndk_old", label: "Old Android NDK versions",
               note: "Keeps the newest NDK plus any version pinned in a build.gradle.",
               risk: .rebuild, category: .android,
               source: .dynamic(.oldNDKs)),

        // ---- Package managers ----
        Target(id: "npm", label: "npm cache",
               note: "Tarball cache. npm refetches as needed.",
               risk: .safe, category: .packages,
               source: .paths(["\(HOME)/.npm/_cacache"])),

        Target(id: "pnpm_yarn", label: "pnpm / yarn stores",
               note: "Package stores. Refetched on next install.",
               risk: .safe, category: .packages,
               source: .paths(["\(HOME)/Library/pnpm/store", "\(HOME)/.cache/yarn",
                               "\(HOME)/Library/Caches/Yarn"])),

        Target(id: "pip", label: "pip & Python caches",
               note: "Wheel cache. pip re-downloads as needed.",
               risk: .safe, category: .packages,
               source: .paths(["\(HOME)/Library/Caches/pip",
                               "\(HOME)/Library/Caches/com.apple.python"])),

        Target(id: "nodegyp_ts", label: "node-gyp & TypeScript caches",
               note: "Header and compile caches.",
               risk: .safe, category: .packages,
               source: .paths(["\(HOME)/Library/Caches/node-gyp",
                               "\(HOME)/Library/Caches/typescript"])),

        Target(id: "brew", label: "Homebrew cache",
               note: "Runs `brew cleanup --prune=all`, then clears the download cache.",
               risk: .safe, category: .packages,
               source: .command("brew cleanup --prune=all; rm -rf ~/Library/Caches/Homebrew/*",
                                measured: ["\(HOME)/Library/Caches/Homebrew"])),

        // ---- Apps ----
        Target(id: "chrome_cache", label: "Chrome caches",
               note: "Code and service-worker caches. Logins and tabs are untouched.",
               risk: .safe, category: .apps,
               source: .paths(["\(HOME)/Library/Caches/Google",
                               "\(HOME)/Library/Application Support/Google/Chrome/*/Service Worker/CacheStorage",
                               "\(HOME)/Library/Application Support/Google/Chrome/*/Code Cache"])),

        Target(id: "vscode_cache", label: "VS Code caches",
               note: "Cache, CachedData and downloaded extension VSIXs. Settings untouched.",
               risk: .safe, category: .apps,
               source: .paths(["\(HOME)/Library/Application Support/Code/Cache",
                               "\(HOME)/Library/Application Support/Code/CachedData",
                               "\(HOME)/Library/Application Support/Code/CachedExtensionVSIXs"])),

        Target(id: "claude_cache", label: "Claude app caches",
               note: "Electron code and GPU caches. Conversations untouched.",
               risk: .safe, category: .apps,
               source: .paths(["\(HOME)/Library/Application Support/Claude/Cache",
                               "\(HOME)/Library/Application Support/Claude/Code Cache",
                               "\(HOME)/Library/Application Support/Claude/GPUCache"])),

        Target(id: "claude_vm", label: "Claude VM bundle",
               note: "Sandbox VM image. Deleting forces a multi-GB re-download next use.",
               risk: .rebuild, category: .apps,
               source: .paths(["\(HOME)/Library/Application Support/Claude/vm_bundles"])),

        Target(id: "claude_sessions", label: "Claude local agent sessions",
               note: "Saved local agent-mode session state.",
               risk: .review, category: .apps,
               source: .paths(["\(HOME)/Library/Application Support/Claude/local-agent-mode-sessions"])),

        Target(id: "playwright", label: "Playwright browsers",
               note: "Downloaded Chromium/Firefox/WebKit. Re-downloaded on next run.",
               risk: .rebuild, category: .apps,
               source: .paths(["\(HOME)/Library/Caches/ms-playwright",
                               "\(HOME)/Library/Caches/ms-playwright-mcp"])),

        // ---- System ----
        Target(id: "logs", label: "User logs",
               note: "~/Library/Logs. Diagnostic output only.",
               risk: .safe, category: .system,
               source: .paths(["\(HOME)/Library/Logs/*"])),

        Target(id: "trash", label: "Trash",
               note: "Empties ~/.Trash permanently.",
               risk: .safe, category: .system,
               source: .paths(["\(HOME)/.Trash/*"])),

        // ---- Projects ----
        Target(id: "proj_builds", label: "Project build folders",
               note: "build/, .next/, dist/, __pycache__ under ~/Documents/Github.",
               risk: .rebuild, category: .projects,
               source: .dynamic(.projectBuilds)),

        Target(id: "node_modules", label: "All node_modules",
               note: "Under ~/Documents/Github. Requires `npm install` afterwards.",
               risk: .rebuild, category: .projects,
               source: .dynamic(.nodeModules)),

        Target(id: "venvs", label: "Python virtualenvs",
               note: "venv/.venv under ~/Documents/Github. Recreate from requirements.txt.",
               risk: .rebuild, category: .projects,
               source: .dynamic(.venvs)),

        // ---- iOS / device data (often the biggest win on a dev machine) ----
        Target(id: "ios_backups", label: "iOS device backups",
               note: "Full device backups. Deleting means you cannot restore from them.",
               risk: .review, category: .system,
               source: .paths(["\(HOME)/Library/Application Support/MobileSync/Backup/*"])),

        Target(id: "ios_updates", label: "Cached iOS software updates",
               note: ".ipsw firmware images. Re-downloaded if you ever need them again.",
               risk: .safe, category: .system,
               source: .paths(["\(HOME)/Library/iTunes/iPhone Software Updates/*",
                               "\(HOME)/Library/iTunes/iPad Software Updates/*"])),

        // ---- Mail ----
        Target(id: "mail_downloads", label: "Mail attachment downloads",
               note: "Attachments Mail cached locally. Still on the server.",
               risk: .review, category: .personal,
               source: .paths(["\(HOME)/Library/Containers/com.apple.mail/Data/Library/Mail Downloads/*"])),

        // ---- All trash bins ----
        Target(id: "trash_volumes", label: "Trash on external volumes",
               note: "Hidden .Trashes folders on mounted drives.",
               risk: .safe, category: .system,
               source: .paths(["/Volumes/*/.Trashes/*"])),

        // ---- Personal ----
        Target(id: "downloads_dmg", label: "Installers in Downloads",
               note: ".dmg/.pkg/.zip you already ran. Re-downloadable from the vendor.",
               risk: .review, category: .personal,
               source: .paths(["\(HOME)/Downloads/*.dmg", "\(HOME)/Downloads/*.pkg",
                               "\(HOME)/Downloads/*.zip"])),

        Target(id: "screenshots", label: "Screenshots on the Desktop",
               note: "Files named \"Screenshot …\" sitting on your Desktop.",
               risk: .review, category: .personal,
               source: .paths(["\(HOME)/Desktop/Screenshot*.png",
                               "\(HOME)/Desktop/Screen Shot*.png"])),
    ]
}
