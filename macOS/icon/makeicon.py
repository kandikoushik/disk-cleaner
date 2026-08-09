#!/usr/bin/env python3
"""
Render the Disk Cleaner app icon.

Two outputs:

  icon.png            flattened 1024 icon, converted to .icns for the bundle
  layers/*.png        the same artwork split into layers, sized and positioned
                      for Icon Composer, which is the only way to author a real
                      Liquid Glass (.icon) asset

A true Liquid Glass icon is layered artwork that the *system* composites —
applying specular highlights, refraction, and the dark/tinted/clear variants at
render time. That cannot be produced from a flat PNG, and Icon Composer ships
GUI-only, so the flattened icon below imitates the look rather than being it.
The layer exports exist so the real thing is a five-minute drag-and-drop away.

Stdlib only; 3x supersampled.
"""
import math
import os
import struct
import sys
import zlib

S = 1024
SS = 3
W = S * SS


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def rounded_rect_sdf(x, y, w, h, r):
    """Signed distance to a rounded rect; negative inside."""
    qx, qy = abs(x - w / 2) - (w / 2 - r), abs(y - h / 2) - (h / 2 - r)
    ax, ay = max(qx, 0.0), max(qy, 0.0)
    return math.hypot(ax, ay) + min(max(qx, qy), 0.0) - r


# Geometry shared by every layer so they stack in register.
PAD = W * 0.055
CW = W - PAD * 2
RADIUS = CW * 0.225
CX = CY = W / 2
DISK_R = CW * 0.29
RING_W = CW * 0.085


def glyph_alpha(x, y):
    """Coverage of the gauge ring + down arrow at a point, 0…1."""
    dx, dy = x - CX, y - CY
    cover = 0.0

    # Gauge ring, open at the lower left, ~71% filled.
    dist = math.hypot(dx, dy)
    ring_d = abs(dist - DISK_R) - RING_W / 2
    if ring_d < 1.0:
        ang = math.degrees(math.atan2(dy, dx)) % 360
        if ang >= 130 or ang <= 50:
            ra = min(max(0.5 - ring_d, 0.0), 1.0)
            swept = (ang - 130) % 360
            cover = max(cover, ra * (1.0 if swept <= 200 else 0.28))

    # Arrow: stem + head.
    sw = CW * 0.052
    stem_top, stem_bot = CY - DISK_R * 0.52, CY + DISK_R * 0.06
    head_h, head_w = DISK_R * 0.46, CW * 0.115
    ty = y - stem_bot

    if abs(dx) <= sw and stem_top <= y <= stem_bot:
        e = min(sw - abs(dx), y - stem_top, stem_bot - y + 2)
        cover = max(cover, min(max(e, 0.0), 1.0))
    elif 0 <= ty <= head_h and abs(dx) <= head_w * (1 - ty / head_h):
        e = min(head_w * (1 - ty / head_h) - abs(dx), ty + 2, head_h - ty)
        cover = max(cover, min(max(e, 0.0), 1.0))

    return cover


def render(mode):
    """mode: 'flat' | 'background' | 'glyph'"""
    top = (0x5B, 0x93, 0xFF)
    bot = (0x1E, 0x3E, 0xC9)
    rows = []

    for py in range(W):
        row = bytearray()
        for px in range(W):
            x, y = px + 0.5, py + 0.5
            d = rounded_rect_sdf(x - PAD, y - PAD, CW, CW, RADIUS)
            plate = min(max(0.5 - d, 0.0), 1.0)

            if mode == "glyph":
                # Glyph on transparency, clipped to the plate.
                a = glyph_alpha(x, y) * plate
                row += bytes((255, 255, 255, int(a * 255)))
                continue

            if plate <= 0.0:
                row += b"\x00\x00\x00\x00"
                continue

            t = (y - PAD) / CW
            r, g, b = lerp(top, bot, min(max(t, 0), 1))

            # Specular sheen across the top, as a glass surface would catch light.
            sheen = max(0.0, 1.0 - (y - PAD) / (CW * 0.5)) ** 2 * 34
            r, g, b = r + sheen, g + sheen, b + sheen

            # Rim light just inside the edge, and a soft inner shade at the base.
            edge = -d
            if 0 < edge < CW * 0.02:
                k = (1 - edge / (CW * 0.02)) ** 2
                lift = 46 * k * (1.0 if y < CY else 0.25)
                r, g, b = r + lift, g + lift, b + lift

            if mode == "flat":
                a = glyph_alpha(x, y)
                if a > 0:
                    # Drop the glyph in white with a faint shadow beneath it.
                    sh = glyph_alpha(x - W * 0.004, y - W * 0.006)
                    if sh > a:
                        k = (sh - a) * 0.35
                        r, g, b = r * (1 - k), g * (1 - k), b * (1 - k)
                    r = r + (255 - r) * a
                    g = g + (255 - g) * a
                    b = b + (255 - b) * a

            row += bytes((int(min(r, 255)), int(min(g, 255)),
                          int(min(b, 255)), int(plate * 255)))
        rows.append(bytes(row))
        if py % 768 == 0:
            print(f"    {mode}: {py}/{W}", file=sys.stderr)
    return rows


def downsample(rows):
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
    print(f"  wrote {path}", file=sys.stderr)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    layers = os.path.join(here, "layers")
    os.makedirs(layers, exist_ok=True)

    write_png(os.path.join(here, "icon.png"), downsample(render("flat")), S)
    write_png(os.path.join(layers, "1-background.png"), downsample(render("background")), S)
    write_png(os.path.join(layers, "2-glyph.png"), downsample(render("glyph")), S)
    print("done", file=sys.stderr)
