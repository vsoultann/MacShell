#!/usr/bin/env python3
"""Build MacShell's AirDrop app icon from Apple's own AirDrop symbol.

The result is a 512 px PNG: Apple's symbol is an Illustrator export (CSS classes, clip paths) that Qt's
SVG renderer draws as nothing, so it is rendered once here with librsvg / ImageMagick instead.

Apple's artwork is not shipped in this repo: the symbol (the one extracted from macOS, on Wikimedia
Commons) is downloaded here and set on a macOS app tile, the way the AirDrop icon looks in Finder.
If the download fails, LocalSend's icon from your icon theme is used instead.

    macshell-airdrop-icon.py [out.svg]
"""
import os
import re
import sys
import urllib.request

URL = "https://upload.wikimedia.org/wikipedia/commons/a/a9/AirDrop_logo.svg"
ICONS = os.path.expanduser("~/.local/share/icons/hicolor")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ICONS, "512x512/apps/macshell-airdrop.png")
OLD_SVG = os.path.join(ICONS, "scalable/apps/macshell-airdrop.svg")


def fetch():
    req = urllib.request.Request(URL, headers={"User-Agent": "MacShell installer (github.com/vsoultann/MacShell)"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read().decode("utf-8", "replace")


def tile(symbol_svg):
    # keep the symbol's own drawing and viewBox, drop its XML prolog / outer attributes
    vb = re.search(r'viewBox="([^"]+)"', symbol_svg)
    viewbox = vb.group(1) if vb else "0 0 397 373.4"
    inner = re.sub(r"^.*?<svg[^>]*>", "", symbol_svg, count=1, flags=re.S)
    inner = re.sub(r"</svg>\s*$", "", inner, flags=re.S)
    # the macOS app tile: a squircle, white to a soft grey, with the usual hairline and lift
    return f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="tileFill" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="1" stop-color="#E9EBEF"/>
    </linearGradient>
    <filter id="lift" x="-10%" y="-10%" width="120%" height="125%">
      <feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#000" flood-opacity="0.28"/>
    </filter>
  </defs>
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#tileFill)" filter="url(#lift)"/>
  <rect x="100.5" y="100.5" width="823" height="823" rx="185" fill="none" stroke="#000" stroke-opacity="0.08"/>
  <svg x="232" y="250" width="560" height="527" viewBox="{viewbox}">
    {inner}
  </svg>
</svg>
'''


def render(svg_text, png_path, size=512):
    import shutil
    import subprocess
    import tempfile
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as t:
        t.write(svg_text)
        src = t.name
    try:
        if shutil.which("rsvg-convert"):
            subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), src, "-o", png_path], check=True)
        elif shutil.which("magick"):
            subprocess.run(["magick", "-background", "none", "-density", "384", src,
                            "-resize", "%dx%d" % (size, size), png_path], check=True)
        else:
            raise RuntimeError("neither rsvg-convert nor magick is installed")
    finally:
        os.unlink(src)


def main():
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    try:
        render(tile(fetch()), OUT)
        # an older hand-drawn SVG of the same name would win the lookup (scalable beats fixed sizes)
        if os.path.lexists(OLD_SVG):
            os.remove(OLD_SVG)
        print("AirDrop icon: Apple's symbol ->", OUT)
        return 0
    except Exception as e:
        # offline or the file moved: LocalSend's icon from the theme is the honest stand-in
        for theme in ("MacTahoe", "McMojave-circle", "MacOS-Like-Light"):
            p = os.path.expanduser(f"~/.local/share/icons/{theme}/apps/scalable/localsend.svg")
            if os.path.exists(p):
                os.makedirs(os.path.dirname(OLD_SVG), exist_ok=True)
                if os.path.lexists(OLD_SVG):
                    os.remove(OLD_SVG)
                os.symlink(p, OLD_SVG)
                print("AirDrop icon: download failed (%s); using LocalSend's icon from %s" % (e, theme))
                return 0
        print("AirDrop icon: download failed and no fallback found:", e, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
