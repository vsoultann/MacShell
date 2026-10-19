#!/bin/sh
# Apple Music: Cider (an Apple Music client for Linux, cider.sh) when it is installed, otherwise Swift, otherwise
# the App Store opens on a search for it. The Dock and the menu bar show either one as "Apple Music".
if flatpak info sh.cider.Cider >/dev/null 2>&1; then exec flatpak run sh.cider.Cider; fi
command -v cider >/dev/null 2>&1 && exec cider
# Swift (an AppImage): its launcher, wherever AppImageLauncher put it
d=$(grep -l '^StartupWMClass=SwiftApp' "$HOME"/.local/share/applications/*.desktop 2>/dev/null | head -n1)
if [ -n "$d" ]; then exec gtk-launch "$(basename "$d" .desktop)"; fi
qs -c MacShell ipc call appstore search "Cider"
