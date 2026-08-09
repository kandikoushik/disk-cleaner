#!/usr/bin/env python3
"""Render the Disk Cleaner app icon to PNG. Stdlib only, 4x supersampled."""
import math
import struct
import zlib
import sys

S = 1024          # final size
SS = 3            # supersample factor
W = S * SS


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def rounded_rect(x, y, w, h, r):
    """Signed distance to a rounded rect (negative inside)."""
    qx, qy = abs(x - w / 2) - (w / 2 - r), abs(y - h / 2) - (h / 2 - r)
    ax, ay = max(qx, 0.0), max(qy, 0.0)
    return math.hypot(ax, ay) + min(max(qx, qy), 0.0) - r


def render():
    # macOS icon grid: content inset ~10%, squircle corner ~22% of content
    pad = W * 0.055
    cw = W - pad * 2
    radius = cw * 0.225

    top = (0x4C, 0x8B, 0xFF)      # bright blue
    bot = (0x1E, 0x3E, 0xC9)      # deep indigo

    cx, cy = W / 2, W / 2
    disk_r = cw * 0.29
    ring_w = cw * 0.085

    rows = []
    for py in range(W):
        row = bytearray()
        for px in range(W):
            x, y = px + 0.5, py + 0.5

            d = rounded_rect(x - pad, y - pad, cw, cw, radius)
            a = min(max(0.5 - d, 0.0), 1.0)          # 1px AA on the plate edge
            if a <= 0.0:
                row += b"\x00\x00\x00\x00"
                continue

            t = (y - pad) / cw
            r, g, b = lerp(top, bot, min(max(t, 0), 1))

            # subtle top sheen
            sheen = max(0.0, 1.0 - (y - pad) / (cw * 0.55)) ** 2 * 26
            r, g, b = r + sheen, g + sheen, b + sheen

            # --- gauge ring: a disk-usage arc, open at the bottom-left ---
            dx, dy = x - cx, y - cy
            dist = math.hypot(dx, dy)
            ring_d = abs(dist - disk_r) - ring_w / 2
            if ring_d < 1.0:
                ang = math.degrees(math.atan2(dy, dx)) % 360
                # track spans 130°..410° (i.e. wraps through the top)
                in_track = ang >= 130 or ang <= 50
                if in_track:
                    ra = min(max(0.5 - ring_d, 0.0), 1.0)
                    swept = (ang - 130) % 360
                    filled = swept <= 200        # ~71% of the 280° track
                    ink = (255, 255, 255) if filled else (255, 255, 255)
                    alpha = ra * (0.97 if filled else 0.26)
                    r = r + (ink[0] - r) * alpha
                    g = g + (ink[1] - g) * alpha
                    b = b + (ink[2] - b) * alpha

            # --- downward arrow in the middle: reclaiming space ---
            sw = cw * 0.052                       # stem half-width
            stem_top, stem_bot = cy - disk_r * 0.52, cy + disk_r * 0.06
            in_stem = abs(dx) <= sw and stem_top <= y <= stem_bot

            head_h = disk_r * 0.46
            head_w = cw * 0.115
            ty = y - stem_bot
            in_head = 0 <= ty <= head_h and abs(dx) <= head_w * (1 - ty / head_h)

            if in_stem or in_head:
                # tiny AA via distance to the nearest boundary
                if in_stem:
                    e = min(sw - abs(dx), y - stem_top, stem_bot - y + 2)
                else:
                    e = min(head_w * (1 - ty / head_h) - abs(dx), ty + 2, head_h - ty)
                aa = min(max(e, 0.0), 1.0)
                r = r + (255 - r) * aa
                g = g + (255 - g) * aa
                b = b + (255 - b) * aa

            row += bytes((int(min(r, 255)), int(min(g, 255)), int(min(b, 255)), int(a * 255)))
        rows.append(bytes(row))
        if py % 512 == 0:
            print(f"  {py}/{W}", file=sys.stderr)
    return rows


def downsample(rows):
    """Box-filter W -> S, premultiplying so edges don't fringe."""
    out = []
    for oy in range(S):
        row = bytearray()
        for ox in range(S):
            tr = tg = tb = ta = 0
            for sy in range(SS):
                src = rows[oy * SS + sy]
                base = (ox * SS) * 4
                for sx in range(SS):
                    o = base + sx * 4
                    a = src[o + 3]
                    tr += src[o] * a
                    tg += src[o + 1] * a
                    tb += src[o + 2] * a
                    ta += a
            if ta:
                row += bytes((tr // ta, tg // ta, tb // ta, ta // (SS * SS)))
            else:
                row += b"\x00\x00\x00\x00"
        out.append(bytes(row))
    return out


def write_png(path, rows, size):
    raw = b"".join(b"\x00" + r for r in rows)

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


if __name__ == "__main__":
    print("rendering…", file=sys.stderr)
    big = render()
    print("downsampling…", file=sys.stderr)
    write_png(sys.argv[1] if len(sys.argv) > 1 else "icon.png", downsample(big), S)
    print("done", file=sys.stderr)
