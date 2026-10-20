#!/usr/bin/env python3
"""Keeps QuickTime Player's full screen clean: while VLC's full-screen window is up, the player window waits on
a hidden workspace, and it comes back where it was when full screen ends.

    macshell-quicktime-watch.py <vlc-pid>

VLC's skin engine keeps raising its own windows, and Hyprland lets a raised X11 window draw over a full-screen
one, so the player sat on top of the movie (frozen, since VLC stops drawing it). No window rule can say "hide
this one while that one is full screen", so this does it, listening to Hyprland's event socket. It ends with VLC.
"""
import json
import os
import socket
import subprocess
import sys
import threading
import time

PARK = "special:quicktime"


def clients():
    try:
        return json.loads(subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=3).stdout)
    except Exception:
        return []


def dispatch(expr):
    subprocess.run(["hyprctl", "dispatch", expr], capture_output=True, timeout=3)


def main(pid):
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    run = os.environ.get("XDG_RUNTIME_DIR", "/run/user/%d" % os.getuid())
    if not sig:
        return 0
    path = os.path.join(run, "hypr", sig, ".socket2.sock")
    parked = {}                 # player address -> the workspace it came from

    def check():
        mine = [c for c in clients() if c.get("pid") == pid]
        full = any(c.get("title") == "VLC (Fullscreen)" and c.get("fullscreen", 0) and c.get("mapped", True)
                   and c["size"][0] > 100 for c in mine)
        for c in mine:
            if c.get("title") != "VLC (TopWindow)":
                continue
            addr = c["address"]
            ws = c["workspace"]["name"]
            if full and addr not in parked and ws != PARK:
                parked[addr] = ws
                dispatch('hl.dsp.window.move({ workspace = "%s", follow = false, window = "address:%s" })' % (PARK, addr))
            elif not full and addr in parked:
                back = parked.pop(addr)
                dispatch('hl.dsp.window.move({ workspace = "%s", follow = false, window = "address:%s" })' % (back, addr))
                dispatch('hl.dsp.focus({ window = "address:%s" })' % addr)

    def alive():
        while True:
            try:
                os.kill(pid, 0)
            except OSError:
                os._exit(0)
            time.sleep(2)

    threading.Thread(target=alive, daemon=True).start()
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(path)
    buf = b""
    while True:
        data = s.recv(4096)
        if not data:
            return 0
        buf += data
        lines = buf.split(b"\n")
        buf = lines.pop()
        if any(l.startswith((b"openwindow>>", b"closewindow>>", b"fullscreen>>", b"windowtitle")) for l in lines):
            time.sleep(0.05)    # let the window settle (VLC maps it, then sets its size)
            check()


if __name__ == "__main__":
    sys.exit(main(int(sys.argv[1])) if len(sys.argv) > 1 else 2)
