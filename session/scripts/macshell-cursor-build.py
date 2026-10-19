#!/usr/bin/env python3
"""Rebuilds MacShell's pointers from Apple's vector drawings: every pointer of the "macOS" and "macOS-White" X cursor
themes is rendered sharp at each size MacShell offers (and their HiDPI doubles), with a fuller, softer macOS-style
drop shadow than the stock bitmaps carry. Plain X cursor files: nothing is rendered at run time.

    macshell-cursor-build.py SRC_DIR

SRC_DIR is a checkout of github.com/ful1e5/apple_cursor (GPL-3.0). The themes must already be installed in
~/.local/share/icons (./install.sh --icons); their names and aliases are kept, only the pictures are redrawn.
Needs rsvg-convert (librsvg) or ImageMagick.
"""
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import tomllib

ICONS = os.path.expanduser("~/.local/share/icons")
THEMES = {"macOS": {"#00FF00": "#000000", "#0000FF": "#FFFFFF"},
          "macOS-White": {"#00FF00": "#FFFFFF", "#0000FF": "#000000"}}
SIZES = [24, 32, 40, 48, 56, 64, 72, 80, 96, 112, 128]
CANVAS = 256

# the macOS pointer's shadow: soft and diffuse, a little below, never sideways (the source's is offset to the left)
SHADOW = ('<feOffset dx="0" dy="5"/><feGaussianBlur stdDeviation="10"/>'
          '<feColorMatrix type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.36 0"/>')


def soften(svg):
    """rounded corners everywhere: round joins on the outlines, and a thin rounded edge of the same colour on
    every filled shape, so tips and corners are softly rounded like the macOS pointer instead of mitred points"""
    def stroke_path(m):
        tag = m.group(0)
        if "stroke-linejoin" in tag:
            return tag
        if "stroke=" in tag:
            add = "" if "stroke-linecap" in tag else ' stroke-linecap="round"'
            return tag.replace("<path", '<path stroke-linejoin="round"' + add, 1)
        fill = re.search(r'fill="(#[0-9A-Fa-f]{6})"', tag)
        if fill:
            return tag.replace("<path", '<path stroke="%s" stroke-width="5" stroke-linejoin="round"' % fill.group(1), 1)
        return tag
    return re.sub(r"<path\b[^>]*>", stroke_path, svg)


def svg_for(path, colours):
    with open(path) as f:
        svg = f.read()
    for a, b in colours.items():
        svg = re.sub(re.escape(a), b, svg, flags=re.I)
    svg = re.sub(r'(<filter[^>]*?)\bx="[^"]*"\s+y="[^"]*"\s+width="[^"]*"\s+height="[^"]*"',
                 r'\1x="0" y="0" width="%d" height="%d"' % (CANVAS, CANVAS), svg)
    svg = re.sub(r'<feOffset[^>]*/>\s*<feGaussianBlur[^>]*/>\s*<feColorMatrix type="matrix" values="[^"]*"/>',
                 SHADOW, svg, count=1)
    return soften(svg)


def rgba(svg_text, size, tmp):
    src = os.path.join(tmp, "c.svg")
    png = os.path.join(tmp, "c.png")
    with open(src, "w") as f:
        f.write(svg_text)
    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), src, "-o", png], check=True)
    else:
        subprocess.run(["magick", "-background", "none", "-density", "384", src, "-resize", "%dx%d!" % (size, size), png], check=True)
    return subprocess.run(["magick", png, "-depth", "8", "rgba:-"], check=True, capture_output=True).stdout


def xcursor(images):
    """images: [(size, xhot, yhot, rgba bytes)] → the bytes of an Xcursor file"""
    n = len(images)
    header = struct.pack("<4sIII", b"Xcur", 16, 0x10000, n)
    pos = 16 + n * 12
    toc, chunks = b"", b""
    for size, xh, yh, px in images:
        toc += struct.pack("<III", 0xfffd0002, size, pos)
        argb = bytearray(len(px))
        for i in range(0, len(px), 4):
            r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
            # premultiplied ARGB, little-endian (B, G, R, A in memory)
            argb[i] = b * a // 255
            argb[i + 1] = g * a // 255
            argb[i + 2] = r * a // 255
            argb[i + 3] = a
        chunk = struct.pack("<IIIIIIIII", 36, 0xfffd0002, size, 1, size, size, xh, yh, 0) + bytes(argb)
        chunks += chunk
        pos += len(chunk)
    return header + toc + chunks


def build(src, name, colours, config):
    cdir = os.path.join(ICONS, name, "cursors")
    if not os.path.isdir(cdir):
        print("skip %s: the theme isn't installed" % name)
        return False
    # a hyprcursor copy from an earlier build would win over these in Hyprland: remove it
    shutil.rmtree(os.path.join(ICONS, name, "hyprcursors"), ignore_errors=True)
    for m in ("manifest.hl", "manifest.hl.off"):
        if os.path.exists(os.path.join(ICONS, name, m)):
            os.unlink(os.path.join(ICONS, name, m))
    done = 0
    tmp = tempfile.mkdtemp(prefix="macshell-cursor-")
    try:
        for key, c in config.get("cursors", {}).items():
            x11 = c.get("x11_name")
            svg_path = os.path.join(src, "svg", os.path.splitext(c.get("png", ""))[0] + ".svg")
            target = os.path.join(cdir, x11 or "")
            if not x11 or not os.path.isfile(svg_path) or not os.path.exists(target) or os.path.islink(target):
                continue        # animated pointers (busy, wait) and aliases keep what the release ships
            svg = svg_for(svg_path, colours)
            fb = config["cursors"].get("fallback_settings", {})
            hx = c.get("x_hotspot", fb.get("x_hotspot", CANVAS / 2))
            hy = c.get("y_hotspot", fb.get("y_hotspot", CANVAS / 2))
            imgs = []
            for size in SIZES:
                imgs.append((size, round(hx * size / CANVAS), round(hy * size / CANVAS), rgba(svg, size, tmp)))
            data = xcursor(imgs)
            with open(target + ".new", "wb") as f:
                f.write(data)
            os.replace(target + ".new", target)
            done += 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("redrew %d %s pointers at %s px" % (done, name, ", ".join(map(str, SIZES))))
    return done > 0


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    with open(os.path.join(sys.argv[1], "configs", "x.build.toml"), "rb") as f:
        config = tomllib.load(f)
    ok = [build(sys.argv[1], n, c, config) for n, c in THEMES.items()]
    return 0 if any(ok) else 1


if __name__ == "__main__":
    sys.exit(main())
