#!/usr/bin/env python3
"""
Disk Cleaner — local control panel for reclaiming macOS disk space.
Stdlib only. Binds to 127.0.0.1 so nothing is exposed off this machine.

Run:  python3 ~/disk-cleaner/server.py
Then: http://127.0.0.1:8777
"""

import http.server
import json
import os
import shutil
import socketserver
import subprocess
import glob
import urllib.parse
from pathlib import Path

HOME = str(Path.home())
PORT = 8777
HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------------------
# Target catalog.
#   kind: "glob"   -> delete the *contents* matched by each pattern
#         "cmd"    -> run a shell command (size measured from `paths`)
#   risk: safe    = pure cache, regenerates silently
#         rebuild = regenerates, but costs a re-download or a rebuild
#         review  = your data; never auto-selected, inspect before deleting
# ---------------------------------------------------------------------------
TARGETS = [
    # ---- safe ----
    dict(id="xcode_derived", label="Xcode DerivedData", risk="safe",
         note="Build intermediates. Xcode regenerates on next build.",
         kind="glob", paths=[f"{HOME}/Library/Developer/Xcode/DerivedData/*"]),
    dict(id="xcode_devsupport", label="Xcode Device Support (iOS/watchOS/tvOS)", risk="safe",
         note="Symbol caches. Re-created when you next plug in a device.",
         kind="glob", paths=[f"{HOME}/Library/Developer/Xcode/iOS DeviceSupport/*",
                             f"{HOME}/Library/Developer/Xcode/watchOS DeviceSupport/*",
                             f"{HOME}/Library/Developer/Xcode/tvOS DeviceSupport/*"]),
    dict(id="xcode_archives", label="Xcode Archives", risk="review",
         note="Shipped-build archives. Needed to re-symbolicate old crash logs.",
         kind="glob", paths=[f"{HOME}/Library/Developer/Xcode/Archives/*"]),
    dict(id="gradle", label="Gradle caches & daemons", risk="safe",
         note="Android build cache. Re-downloads dependencies on next build.",
         kind="glob", paths=[f"{HOME}/.gradle/caches", f"{HOME}/.gradle/daemon",
                             f"{HOME}/.gradle/wrapper/dists"]),
    dict(id="npm", label="npm cache", risk="safe",
         note="Tarball cache. npm refetches as needed.",
         kind="glob", paths=[f"{HOME}/.npm/_cacache"]),
    dict(id="pnpm_yarn", label="pnpm / yarn stores", risk="safe",
         note="Package stores. Refetched on next install.",
         kind="glob", paths=[f"{HOME}/Library/pnpm/store", f"{HOME}/.cache/yarn",
                             f"{HOME}/Library/Caches/Yarn"]),
    dict(id="pip", label="pip & Python caches", risk="safe",
         note="Wheel cache. pip re-downloads as needed.",
         kind="glob", paths=[f"{HOME}/Library/Caches/pip",
                             f"{HOME}/Library/Caches/com.apple.python"]),
    dict(id="swiftpm", label="SwiftPM cache", risk="safe",
         note="Swift package clones. Re-resolved on next build.",
         kind="glob", paths=[f"{HOME}/Library/Caches/org.swift.swiftpm"]),
    dict(id="nodegyp_ts", label="node-gyp + TypeScript caches", risk="safe",
         note="Header/compile caches.",
         kind="glob", paths=[f"{HOME}/Library/Caches/node-gyp",
                             f"{HOME}/Library/Caches/typescript"]),
    dict(id="brew", label="Homebrew cache", risk="safe",
         note="Runs `brew cleanup --prune=all` then clears the download cache.",
         kind="cmd", cmd="brew cleanup --prune=all; rm -rf ~/Library/Caches/Homebrew/*",
         paths=[f"{HOME}/Library/Caches/Homebrew"]),
    dict(id="logs", label="User logs", risk="safe",
         note="~/Library/Logs. Diagnostic output only.",
         kind="glob", paths=[f"{HOME}/Library/Logs/*"]),
    dict(id="trash", label="Trash", risk="safe",
         note="Empties ~/.Trash permanently.",
         kind="glob", paths=[f"{HOME}/.Trash/*"]),

    # ---- browser / app caches ----
    dict(id="chrome_cache", label="Chrome caches", risk="safe",
         note="Clears code + service-worker caches. Logins and tabs are untouched.",
         kind="glob", paths=[f"{HOME}/Library/Caches/Google",
                             f"{HOME}/Library/Application Support/Google/Chrome/*/Service Worker/CacheStorage",
                             f"{HOME}/Library/Application Support/Google/Chrome/*/Code Cache"]),
    dict(id="vscode_cache", label="VS Code caches", risk="safe",
         note="Cache, CachedData and downloaded extension VSIXs. Settings untouched.",
         kind="glob", paths=[f"{HOME}/Library/Application Support/Code/Cache",
                             f"{HOME}/Library/Application Support/Code/CachedData",
                             f"{HOME}/Library/Application Support/Code/CachedExtensionVSIXs"]),
    dict(id="claude_cache", label="Claude app caches", risk="safe",
         note="Electron code/GPU caches. Conversations untouched.",
         kind="glob", paths=[f"{HOME}/Library/Application Support/Claude/Cache",
                             f"{HOME}/Library/Application Support/Claude/Code Cache",
                             f"{HOME}/Library/Application Support/Claude/GPUCache"]),
    dict(id="claude_vm", label="Claude VM bundle", risk="rebuild",
         note="Sandbox VM image. Deleting forces a multi-GB re-download next use.",
         kind="glob", paths=[f"{HOME}/Library/Application Support/Claude/vm_bundles"]),
    dict(id="claude_sessions", label="Claude local agent sessions", risk="review",
         note="Saved local agent-mode session state.",
         kind="glob", paths=[f"{HOME}/Library/Application Support/Claude/local-agent-mode-sessions"]),
    dict(id="playwright", label="Playwright browsers", risk="rebuild",
         note="Downloaded Chromium/Firefox/WebKit. Re-downloaded on next run.",
         kind="glob", paths=[f"{HOME}/Library/Caches/ms-playwright",
                             f"{HOME}/Library/Caches/ms-playwright-mcp"]),

    # ---- simulators / SDKs ----
    dict(id="sim_unavailable", label="Unavailable iOS simulators", risk="safe",
         note="Runs `xcrun simctl delete unavailable` — removes runtime-less devices.",
         kind="cmd", cmd="xcrun simctl delete unavailable",
         paths=[f"{HOME}/Library/Developer/CoreSimulator/Devices"]),
    dict(id="sim_all", label="ALL simulator devices", risk="rebuild",
         note="Erases every simulator and its installed apps. Devices are re-creatable.",
         kind="cmd", cmd="xcrun simctl delete all",
         paths=[f"{HOME}/Library/Developer/CoreSimulator/Devices"]),
    dict(id="ndk_old", label="Old Android NDK versions", risk="rebuild",
         note="Keeps the newest NDK plus any version pinned in a build.gradle.",
         kind="cmd", cmd="__ndk_prune__",
         paths=[f"{HOME}/Library/Android/sdk/ndk"]),

    # ---- project artifacts ----
    dict(id="proj_builds", label="Project build folders (ios/android/.next/dist)", risk="rebuild",
         note="native build/, .next/, __pycache__ under ~/Documents/Github. Regenerated on build.",
         kind="cmd", cmd="__proj_builds__",
         paths=["__proj_builds__"]),
    dict(id="node_modules", label="All node_modules under ~/Documents/Github", risk="rebuild",
         note="Requires `npm install` in each project afterwards.",
         kind="cmd", cmd="__node_modules__",
         paths=["__node_modules__"]),
    dict(id="venvs", label="Python virtualenvs under ~/Documents/Github", risk="rebuild",
         note="venv/.venv folders. Recreate with pip install -r requirements.txt.",
         kind="cmd", cmd="__venvs__",
         paths=["__venvs__"]),

    # ---- your data ----
    dict(id="downloads_dmg", label="Installers in Downloads (.dmg/.pkg/.zip)", risk="review",
         note="App installers you already ran. Re-downloadable from the vendor.",
         kind="glob", paths=[f"{HOME}/Downloads/*.dmg", f"{HOME}/Downloads/*.pkg",
                             f"{HOME}/Downloads/*.zip"]),
]

GITHUB = f"{HOME}/Documents/Github"

# Category shown in the UI, keyed by target id.
GROUPS = {
    "xcode_derived": "Xcode", "xcode_devsupport": "Xcode", "xcode_archives": "Xcode",
    "swiftpm": "Xcode", "sim_unavailable": "Simulators", "sim_all": "Simulators",
    "gradle": "Android", "ndk_old": "Android",
    "npm": "Package managers", "pnpm_yarn": "Package managers", "pip": "Package managers",
    "brew": "Package managers", "nodegyp_ts": "Package managers",
    "chrome_cache": "Apps", "vscode_cache": "Apps", "claude_cache": "Apps",
    "claude_vm": "Apps", "claude_sessions": "Apps", "playwright": "Apps",
    "logs": "System", "trash": "System",
    "proj_builds": "Projects", "node_modules": "Projects", "venvs": "Projects",
    "downloads_dmg": "Personal",
}
for _t in TARGETS:
    _t["group"] = GROUPS.get(_t["id"], "System")


# ---------------------------------------------------------------------------
# Sizing helpers
# ---------------------------------------------------------------------------
_DU_CACHE = {}
_DU_TTL = 120          # seconds; a rescan after this re-measures


def du_bytes(path, fresh=False):
    """Disk usage of a path in bytes; 0 if missing. Cached briefly — the same
    paths get measured by the scan, the composition chart and the hog list."""
    import time
    if not os.path.exists(path):
        _DU_CACHE.pop(path, None)
        return 0
    now = time.time()
    hit = _DU_CACHE.get(path)
    if hit and not fresh and now - hit[0] < _DU_TTL:
        return hit[1]
    try:
        out = subprocess.run(["du", "-sk", path], capture_output=True, text=True, timeout=180)
        if out.returncode != 0 and not out.stdout.strip():
            return 0
        val = int(out.stdout.split()[0]) * 1024
    except Exception:
        return 0
    _DU_CACHE[path] = (now, val)
    return val


def du_invalidate(path):
    """Drop cached sizes for a path and anything under or above it."""
    for k in [k for k in _DU_CACHE if k.startswith(path) or path.startswith(k)]:
        _DU_CACHE.pop(k, None)


def find_dirs(names, maxdepth=5):
    """Find directories by name under ~/Documents/Github, not descending into matches."""
    if not os.path.isdir(GITHUB):
        return []
    expr = []
    for i, n in enumerate(names):
        if i:
            expr.append("-o")
        expr += ["-name", n]
    cmd = ["find", GITHUB, "-maxdepth", str(maxdepth), "-type", "d", "("] + expr + [")", "-prune"]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
        return [p for p in out.stdout.splitlines() if p.strip()]
    except Exception:
        return []


BUILD_NAMES = ["build", ".next", "dist", "__pycache__", "DerivedData"]
VENV_NAMES = ["venv", ".venv"]


def dynamic_paths(token):
    if token == "__node_modules__":
        return find_dirs(["node_modules"], maxdepth=4)
    if token == "__venvs__":
        return [p for p in find_dirs(VENV_NAMES, maxdepth=4) if "node_modules" not in p]
    if token == "__proj_builds__":
        return [p for p in find_dirs(BUILD_NAMES, maxdepth=5) if "node_modules" not in p]
    return []


def pinned_ndks():
    """NDK versions referenced by any gradle file — never delete these."""
    pinned = set()
    try:
        out = subprocess.run(
            ["grep", "-rhoE", r'ndkVersion[^"\']*["\']([0-9.]+)["\']', GITHUB,
             "--include=*.gradle", "--include=*.kts", "--include=*.properties"],
            capture_output=True, text=True, timeout=120)
        for line in out.stdout.splitlines():
            for tok in line.replace('"', " ").replace("'", " ").split():
                if tok and tok[0].isdigit():
                    pinned.add(tok)
    except Exception:
        pass
    return pinned


def ndk_removable():
    root = f"{HOME}/Library/Android/sdk/ndk"
    if not os.path.isdir(root):
        return []
    versions = sorted(os.listdir(root))
    if len(versions) <= 1:
        return []
    keep = set(pinned_ndks())
    keep.add(versions[-1])  # newest
    return [os.path.join(root, v) for v in versions if v not in keep]


def expand(target):
    """Concrete paths this target would remove."""
    out = []
    for p in target["paths"]:
        if p.startswith("__"):
            out += dynamic_paths(p)
        else:
            out += glob.glob(p)
    if target["id"] == "ndk_old":
        out = ndk_removable()
    if target["id"] == "sim_unavailable":
        out = unavailable_sim_dirs()
    return out


def unavailable_sim_dirs():
    """Device folders whose runtime is no longer installed."""
    root = f"{HOME}/Library/Developer/CoreSimulator/Devices"
    if not os.path.isdir(root):
        return []
    try:
        out = subprocess.run(["xcrun", "simctl", "list", "devices", "-j"],
                             capture_output=True, text=True, timeout=120)
        data = json.loads(out.stdout)
    except Exception:
        return []
    dirs = []
    for runtime, devices in data.get("devices", {}).items():
        stale = "unavailable" in runtime.lower()
        for d in devices:
            if stale or not d.get("isAvailable", True):
                p = os.path.join(root, d.get("udid", ""))
                if d.get("udid") and os.path.isdir(p):
                    dirs.append(p)
    return dirs


def measure(target):
    if target["id"] == "ndk_old":
        return sum(du_bytes(p) for p in ndk_removable())
    if target["id"] == "sim_unavailable":
        return sum(du_bytes(p) for p in unavailable_sim_dirs())
    return sum(du_bytes(p) for p in expand(target))


HOG_ROOTS = [
    f"{HOME}/Documents", f"{HOME}/Downloads", f"{HOME}/Desktop", f"{HOME}/Movies",
    f"{HOME}/Pictures", f"{HOME}/Music", f"{HOME}/Library/Application Support",
    f"{HOME}/Library/Caches", f"{HOME}/Library/Developer", f"{HOME}/Library/Android",
    f"{HOME}/Library/Containers", f"{HOME}/Library/Group Containers",
    f"{HOME}/.gradle", f"{HOME}/.npm", f"{HOME}/.cache",
]


# ---------------------------------------------------------------------------
# Activity: processes and listening ports
# ---------------------------------------------------------------------------
# Killing any of these would take the desktop down with it.
PROTECTED = {
    "kernel_task", "launchd", "WindowServer", "loginwindow", "logind", "systemstats",
    "Finder", "Dock", "SystemUIServer", "coreaudiod", "opendirectoryd", "securityd",
    "mds", "mds_stores", "mdworker", "distnoted", "cfprefsd", "UserEventAgent",
    "Disk Cleaner", "DiskCleaner", "Python",
}


def processes(limit=25):
    """Top processes by memory, with CPU alongside."""
    out = []
    try:
        p = subprocess.run(
            ["ps", "-axo", "pid=,ppid=,user=,pcpu=,pmem=,rss=,comm="],
            capture_output=True, text=True, timeout=30)
        me = os.environ.get("USER", "")
        for line in p.stdout.splitlines():
            parts = line.split(None, 6)
            if len(parts) < 7:
                continue
            pid, ppid, user, cpu, mem, rss, comm = parts
            try:
                name = os.path.basename(comm.strip())
                out.append(dict(pid=int(pid), user=user, cpu=float(cpu),
                                mem=float(mem), rss=int(rss) * 1024,
                                name=name, cmd=comm.strip(),
                                mine=(user == me),
                                protected=name in PROTECTED))
            except Exception:
                pass
    except Exception:
        pass
    out.sort(key=lambda x: -x["rss"])
    return out[:limit]


def ports():
    """TCP sockets in LISTEN state, with the process holding them."""
    out, seen = [], set()
    try:
        p = subprocess.run(["lsof", "-nP", "-iTCP", "-sTCP:LISTEN"],
                           capture_output=True, text=True, timeout=40)
        for line in p.stdout.splitlines()[1:]:
            f = line.split()
            if len(f) < 9:
                continue
            # NAME is the last column, but lsof appends "(LISTEN)" after it.
            while f and f[-1].startswith("("):
                f.pop()
            if len(f) < 9:
                continue
            name, pid, user, addr = f[0], f[1], f[2], f[-1]
            if ":" not in addr:
                continue
            host, port = addr.rsplit(":", 1)
            key = (port, pid)
            if key in seen:
                continue
            seen.add(key)
            try:
                out.append(dict(port=int(port), pid=int(pid), name=name, user=user,
                                addr=host or "*",
                                local=host in ("127.0.0.1", "[::1]", "localhost"),
                                protected=name in PROTECTED))
            except Exception:
                pass
    except Exception:
        pass
    out.sort(key=lambda x: x["port"])
    return out


def kill_pid(pid, force=False):
    """Terminate a process the user owns. Never touches the protected list."""
    import signal
    try:
        pid = int(pid)
    except Exception:
        return dict(ok=False, error="bad pid")
    if pid <= 100:
        return dict(ok=False, error="refused: system pid")
    proc = next((p for p in processes(9999) if p["pid"] == pid), None)
    if not proc:
        return dict(ok=False, error="no such process")
    if proc["protected"]:
        return dict(ok=False, error=f"refused: {proc['name']} is protected")
    if not proc["mine"]:
        return dict(ok=False, error="refused: not your process")
    try:
        os.kill(pid, signal.SIGKILL if force else signal.SIGTERM)
        return dict(ok=True, name=proc["name"])
    except PermissionError:
        return dict(ok=False, error="permission denied")
    except ProcessLookupError:
        return dict(ok=False, error="already gone")
    except Exception as e:
        return dict(ok=False, error=str(e))


def space_hogs(limit=14):
    """Read-only: biggest folders one level inside the usual suspects."""
    found = []
    for root in HOG_ROOTS:
        if not os.path.isdir(root):
            continue
        try:
            kids = [os.path.join(root, k) for k in os.listdir(root) if not k.startswith(".")]
        except Exception:
            continue
        if len(kids) > 40:
            kids = kids[:40]
        for k in kids:
            s = du_bytes(k)
            if s > 500 * 1024 * 1024:      # only things over 500 MB
                found.append(dict(path=k, name=os.path.basename(k),
                                  parent=os.path.basename(root), size=s))
    found.sort(key=lambda x: -x["size"])
    return found[:limit]


def disk_stats():
    st = os.statvfs("/System/Volumes/Data")
    total = st.f_blocks * st.f_frsize
    free = st.f_bavail * st.f_frsize
    return dict(total=total, free=free, used=total - free)


HISTORY = os.path.join(HOME, ".disk-cleaner-history.json")


def history_read():
    try:
        with open(HISTORY) as f:
            return json.load(f)
    except Exception:
        return []


def history_add():
    """Record one free-space sample, at most one every 10 minutes."""
    import time
    h = history_read()
    now = int(time.time())
    if h and now - h[-1]["t"] < 600:
        h[-1] = dict(t=now, free=disk_stats()["free"])
    else:
        h.append(dict(t=now, free=disk_stats()["free"]))
    h = h[-180:]
    try:
        with open(HISTORY, "w") as f:
            json.dump(h, f)
    except Exception:
        pass
    return h


def big_files(limit=15, min_mb=300):
    """Largest individual files anywhere in HOME. Spotlight first (instant),
    falling back to find when the index is unavailable."""
    seen, out = set(), []
    try:
        p = subprocess.run(
            ["mdfind", "-onlyin", HOME, f"kMDItemFSSize > {min_mb * 1000 * 1000}"],
            capture_output=True, text=True, timeout=60)
        for line in p.stdout.splitlines():
            if os.path.isfile(line) and line not in seen:
                seen.add(line)
                try:
                    out.append(dict(path=line, name=os.path.basename(line),
                                    size=os.path.getsize(line),
                                    where=os.path.dirname(line).replace(HOME, "~")))
                except Exception:
                    pass
    except Exception:
        pass

    if not out:  # Spotlight off or index cold
        for r in [f"{HOME}/Downloads", f"{HOME}/Desktop", f"{HOME}/Documents",
                  f"{HOME}/Movies", f"{HOME}/Library"]:
            if not os.path.isdir(r):
                continue
            try:
                p = subprocess.run(
                    ["find", r, "-maxdepth", "5", "-type", "f", "-size", f"+{min_mb}M"],
                    capture_output=True, text=True, timeout=90)
                for line in p.stdout.splitlines():
                    if line in seen:
                        continue
                    seen.add(line)
                    try:
                        out.append(dict(path=line, name=os.path.basename(line),
                                        size=os.path.getsize(line),
                                        where=os.path.dirname(line).replace(HOME, "~")))
                    except Exception:
                        pass
            except Exception:
                pass

    out.sort(key=lambda x: -x["size"])
    return out[:limit]


def stale_files(limit=15, min_mb=100, days=365):
    """Big files you have not opened in a long time — prime deletion candidates."""
    import time
    out = []
    now = time.time()
    cutoff = days * 86400
    # Last-used first; many files have no last-used date, so fall back to
    # content-change date, which is always populated.
    queries = [
        f"kMDItemFSSize > {min_mb * 1000 * 1000} && "
        f"kMDItemLastUsedDate < $time.now(-{cutoff})",
        f"kMDItemFSSize > {min_mb * 1000 * 1000} && "
        f"kMDItemFSContentChangeDate < $time.now(-{cutoff})",
    ]
    seen = set()
    for q in queries:
        try:
            p = subprocess.run(["mdfind", "-onlyin", HOME, q],
                               capture_output=True, text=True, timeout=60)
            for line in p.stdout.splitlines():
                if line in seen or not os.path.isfile(line):
                    continue
                seen.add(line)
                try:
                    age = int((now - os.path.getmtime(line)) / 86400)
                    if age < days:
                        continue
                    out.append(dict(path=line, name=os.path.basename(line),
                                    size=os.path.getsize(line), days=age,
                                    where=os.path.dirname(line).replace(HOME, "~")))
                except Exception:
                    pass
        except Exception:
            pass
        if out:
            break
    out.sort(key=lambda x: -x["size"])
    return out[:limit]


COMPOSITION = [
    ("Documents", f"{HOME}/Documents"),
    ("Library", f"{HOME}/Library"),
    ("Downloads", f"{HOME}/Downloads"),
    ("Developer", f"{HOME}/Library/Developer"),
    ("Desktop", f"{HOME}/Desktop"),
    ("Media", f"{HOME}/Movies"),
]


_COMP_RUNNING = False


def composition_ready():
    """True once every folder the chart needs has a cached size."""
    import time
    now = time.time()
    for _, p in COMPOSITION:
        if not os.path.isdir(p):
            continue
        hit = _DU_CACHE.get(p)
        if not hit or now - hit[0] >= _DU_TTL:
            return False
    return True


def composition_kick():
    """Measure the composition folders off the request thread."""
    global _COMP_RUNNING
    if _COMP_RUNNING:
        return
    _COMP_RUNNING = True

    def run():
        global _COMP_RUNNING
        try:
            for _, p in COMPOSITION:
                du_bytes(p)
        finally:
            _COMP_RUNNING = False

    import threading
    threading.Thread(target=run, daemon=True).start()


def composition():
    """What is actually filling the disk: your folders, the system, free space.
    Uses only already-cached sizes so the request never blocks."""
    d = disk_stats()
    parts, home_total = [], 0
    lib = 0
    for name, path in COMPOSITION:
        hit = _DU_CACHE.get(path)
        s = hit[1] if hit else 0
        if name == "Library":
            lib = s
            continue                      # counted below, minus Developer
        if name == "Developer":
            parts.append(dict(name="Developer", size=s))
            home_total += s
            continue
        parts.append(dict(name=name, size=s))
        home_total += s
    dev = next((p["size"] for p in parts if p["name"] == "Developer"), 0)
    rest_lib = max(0, lib - dev)
    parts.append(dict(name="Library", size=rest_lib))
    home_total += rest_lib

    parts = [p for p in parts if p["size"] > 0]
    parts.sort(key=lambda p: -p["size"])
    parts.append(dict(name="System & other", size=max(0, d["used"] - home_total)))
    parts.append(dict(name="Free", size=d["free"]))
    ready = composition_ready()
    if not ready:
        composition_kick()
    return dict(parts=parts, total=d["total"], ready=ready)


# ---------------------------------------------------------------------------
# Deletion
# ---------------------------------------------------------------------------
def rm(path):
    try:
        if os.path.islink(path) or os.path.isfile(path):
            os.remove(path)
        elif os.path.isdir(path):
            shutil.rmtree(path, ignore_errors=True)
        du_invalidate(path)
        return True
    except Exception:
        return False


def guard(path):
    """Refuse anything outside HOME, or HOME itself."""
    rp = os.path.realpath(path)
    return rp.startswith(HOME + os.sep) and rp != HOME


def clean(target):
    before = disk_stats()["free"]
    removed, skipped = [], []

    if target["kind"] == "cmd":
        c = target["cmd"]
        if c == "__ndk_prune__":
            for p in ndk_removable():
                (removed if guard(p) and rm(p) else skipped).append(p)
        elif c in ("__node_modules__", "__venvs__", "__proj_builds__"):
            for p in dynamic_paths(c):
                (removed if guard(p) and rm(p) else skipped).append(p)
        else:
            try:
                subprocess.run(c, shell=True, capture_output=True, text=True, timeout=900)
                removed.append(f"$ {c}")
            except Exception as e:
                skipped.append(f"{c}: {e}")
    else:
        for p in expand(target):
            (removed if guard(p) and rm(p) else skipped).append(p)

    freed = max(0, disk_stats()["free"] - before)
    return dict(id=target["id"], label=target["label"],
                removed=len(removed), skipped=len(skipped), freed=freed,
                sample=removed[:8])


# ---------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        route = urllib.parse.urlparse(self.path).path
        if route in ("/", "/index.html"):
            with open(os.path.join(HERE, "index.html"), "rb") as f:
                return self._send(200, f.read(), "text/html; charset=utf-8")
        if route == "/api/disk":
            return self._send(200, json.dumps(disk_stats()))
        if route == "/api/targets":
            # Instant: metadata only, so the UI can paint immediately.
            return self._send(200, json.dumps(dict(
                items=[dict(id=t["id"], label=t["label"], risk=t["risk"],
                            note=t["note"], group=t.get("group", "System"))
                       for t in TARGETS],
                disk=disk_stats())))
        if route == "/api/size":
            tid = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query).get("id", [""])[0]
            t = next((x for x in TARGETS if x["id"] == tid), None)
            if not t:
                return self._send(404, json.dumps(dict(error="unknown target")))
            return self._send(200, json.dumps(dict(
                id=tid, size=measure(t), count=len(expand(t)))))
        if route == "/api/scan":
            items = []
            for t in TARGETS:
                items.append(dict(id=t["id"], label=t["label"], risk=t["risk"],
                                  note=t["note"], size=measure(t),
                                  count=len(ndk_removable() if t["id"] == "ndk_old" else expand(t))))
            return self._send(200, json.dumps(dict(items=items, disk=disk_stats())))
        if route == "/api/processes":
            return self._send(200, json.dumps(dict(procs=processes())))
        if route == "/api/ports":
            return self._send(200, json.dumps(dict(ports=ports())))
        if route == "/api/stale":
            return self._send(200, json.dumps(dict(files=stale_files())))
        if route == "/api/composition":
            return self._send(200, json.dumps(composition()))
        if route == "/api/history":
            return self._send(200, json.dumps(dict(history=history_add())))
        if route == "/api/bigfiles":
            return self._send(200, json.dumps(dict(files=big_files())))
        if route == "/api/hogs":
            return self._send(200, json.dumps(dict(hogs=space_hogs())))
        if route == "/api/reveal":
            p = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query).get("path", [""])[0]
            if p and os.path.exists(p) and os.path.realpath(p).startswith(HOME):
                subprocess.run(["open", "-R", p], capture_output=True)
                return self._send(200, json.dumps(dict(ok=True)))
            return self._send(400, json.dumps(dict(ok=False)))
        if route == "/api/detail":
            tid = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query).get("id", [""])[0]
            t = next((x for x in TARGETS if x["id"] == tid), None)
            if not t:
                return self._send(404, json.dumps(dict(error="unknown target")))
            paths = ndk_removable() if tid == "ndk_old" else expand(t)
            rows = sorted(((p, du_bytes(p)) for p in paths), key=lambda r: -r[1])[:200]
            return self._send(200, json.dumps(dict(
                id=tid, label=t["label"], paths=[dict(path=p, size=s) for p, s in rows])))
        self._send(404, json.dumps(dict(error="not found")))

    def do_POST(self):
        route = urllib.parse.urlparse(self.path).path
        n = int(self.headers.get("Content-Length", 0))
        try:
            payload = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            return self._send(400, json.dumps(dict(error="bad json")))

        if route == "/api/clean":
            ids = payload.get("ids", [])
            results = [clean(t) for t in TARGETS if t["id"] in ids]
            return self._send(200, json.dumps(dict(results=results, disk=disk_stats())))

        if route == "/api/kill":
            return self._send(200, json.dumps(
                kill_pid(payload.get("pid"), bool(payload.get("force")))))

        if route == "/api/rmpath":
            # Delete one specific path shown in the expanded list.
            p = payload.get("path", "")
            if not p or not os.path.exists(p) or not guard(p):
                return self._send(400, json.dumps(dict(ok=False, error="refused")))
            before = disk_stats()["free"]
            ok = rm(p)
            return self._send(200, json.dumps(dict(
                ok=ok, freed=max(0, disk_stats()["free"] - before), disk=disk_stats())))

        self._send(404, json.dumps(dict(error="not found")))


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    import sys

    port = PORT
    for i, a in enumerate(sys.argv[1:]):
        if a == "--port" and i + 2 <= len(sys.argv[1:]):
            port = int(sys.argv[i + 2])
        elif a.startswith("--port="):
            port = int(a.split("=", 1)[1])

    # Warm the expensive du() results in the background so the composition
    # chart and hog list are already measured by the time they are asked for.
    def warm():
        for _, p in COMPOSITION:
            du_bytes(p)
        space_hogs()

    import threading
    threading.Thread(target=warm, daemon=True).start()

    with Server(("127.0.0.1", port), Handler) as httpd:
        # The host app waits for this line before loading the page.
        print(f"READY http://127.0.0.1:{port}", flush=True)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nstopped")
