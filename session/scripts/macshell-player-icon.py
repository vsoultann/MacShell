#!/usr/bin/env python3
"""MacShell's Player icon: Apple's QuickTime Player icon, downloaded from Wikimedia Commons and rendered to a
512 px PNG (~/.local/share/icons/hicolor/512x512/apps/macshell-player.png). Apple's artwork is not shipped in
the repo. If the download fails, the theme's video-player icon is used (the .desktop file falls back by name).

    macshell-player-icon.py [out.png]
"""
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request

URL = "https://upload.wikimedia.org/wikipedia/commons/4/42/Quicktime-Logo.svg"
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.local/share/icons/hicolor/512x512/apps/macshell-player.png")


def main():
    req = urllib.request.Request(URL, headers={"User-Agent": "MacShell installer (github.com/vsoultann/MacShell)"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            svg = r.read()
    except Exception as e:
        print("Player icon: download failed (%s), keeping the theme's icon" % e)
        return 0
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".svg", delete=False) as t:
        t.write(svg)
        src = t.name
    try:
        if shutil.which("rsvg-convert"):
            subprocess.run(["rsvg-convert", "-w", "512", "-h", "512", "--keep-aspect-ratio", src, "-o", OUT], check=True)
        else:
            subprocess.run(["magick", "-background", "none", "-density", "384", src, "-resize", "512x512", OUT], check=True)
        print("Player icon: Apple's QuickTime Player ->", OUT)
    finally:
        os.unlink(src)
    return 0


if __name__ == "__main__":
    sys.exit(main())
