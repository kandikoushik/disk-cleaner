import AppKit
import WebKit

// ---------------------------------------------------------------------------
// Disk Cleaner — native shell around the local cleanup server.
// Spawns server.py on a free loopback port, shows it in a WKWebView, and
// guarantees the server dies with the app.
// ---------------------------------------------------------------------------

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    var window: NSWindow!
    var web: WKWebView!
    var server: Process?
    var port: Int = 0

    // ---- pick a free loopback port so two launches never collide ----
    func freePort() -> Int {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return 8777 }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let ok = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                // Darwin. qualifier: NSObject also declares a `bind`.
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
        guard ok else { return 8777 }
        var out = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let got = withUnsafeMutablePointer(to: &out) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &len) == 0
            }
        }
        return got ? Int(UInt16(bigEndian: out.sin_port)) : 8777
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        buildMenu()
        buildWindow()
        startServer()
    }

    func buildWindow() {
        let rect = NSRect(x: 0, y: 0, width: 900, height: 760)
        // No .fullSizeContentView: the page owns a sticky header of its own, and
        // letting content slide under the title bar made the two collide.
        window = NSWindow(contentRect: rect,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Disk Cleaner"
        window.minSize = NSSize(width: 620, height: 480)
        window.setFrameAutosaveName("DiskCleanerMain")
        window.center()

        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()
        web = WKWebView(frame: rect, configuration: cfg)
        web.autoresizingMask = [.width, .height]
        web.navigationDelegate = self
        web.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) { web.underPageBackgroundColor = .windowBackgroundColor }
        window.contentView = web

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func startServer() {
        let res = Bundle.main.resourceURL!
        let script = res.appendingPathComponent("server.py")
        port = freePort()

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["python3", script.path, "--port", String(port)]
        p.currentDirectoryURL = res
        // Inherit a login-shell PATH so `brew` and `xcrun` resolve inside the sandboxless app.
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        p.environment = env

        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()

        // Load the page only once the server prints READY.
        pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            guard let self else { return }
            let s = String(data: h.availableData, encoding: .utf8) ?? ""
            if s.contains("READY") {
                pipe.fileHandleForReading.readabilityHandler = nil
                DispatchQueue.main.async { self.load() }
            }
        }

        do {
            try p.run()
            server = p
        } catch {
            showFailure("Could not start the helper.\n\n\(error.localizedDescription)")
            return
        }

        // Safety net: if READY never arrives, try anyway, then report.
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.web.url == nil else { return }
            self.load()
        }
    }

    func load() {
        guard let u = URL(string: "http://127.0.0.1:\(port)/") else { return }
        web.load(URLRequest(url: u))
    }

    func webView(_ w: WKWebView, didFail nav: WKNavigation!, withError e: Error) {
        showFailure("The helper did not respond on port \(port).")
    }

    func showFailure(_ msg: String) {
        let a = NSAlert()
        a.messageText = "Disk Cleaner could not start"
        a.informativeText = msg + "\n\nPython 3 is required. Install the Command Line Tools with:\n    xcode-select --install"
        a.alertStyle = .critical
        a.addButton(withTitle: "Quit")
        a.runModal()
        NSApp.terminate(nil)
    }

    // ---- lifecycle: never leave the server orphaned ----
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ n: Notification) {
        server?.terminate()
        server?.waitUntilExit()
    }

    func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Disk Cleaner",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Disk Cleaner",
                        action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Disk Cleaner",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let r = NSMenuItem(title: "Rescan", action: #selector(reload), keyEquivalent: "r")
        r.target = self
        viewMenu.addItem(r)
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        let winItem = NSMenuItem()
        let winMenu = NSMenu(title: "Window")
        winMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        winMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        winItem.submenu = winMenu
        main.addItem(winItem)
        NSApp.windowsMenu = winMenu

        NSApp.mainMenu = main
    }

    @objc func reload() { web.reload() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
