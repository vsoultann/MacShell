#!/bin/sh
# Finder in MacShell: Dolphin, dressed as Finder (session/qt + macshell-kde-theme.sh), at a folder.
#   macshell-finder.sh [folder|file|file://…]      (a file opens its folder with the file selected)
# finder.qss (the title, the path bar) only applies when Dolphin is started with it, and the sidebar's Finder names
# (Favorites, Locations…) come from the session's own English (en@macshell), so the shell opens Finder through here.
# the session's own KDE look (session/qt): set here too, for whatever started us without the session's environment
q="$HOME/.config/hypr-macshell/qt"
case ":${XDG_CONFIG_DIRS:-}:" in *":$q/xdg:"*) ;; *) export XDG_CONFIG_DIRS="$q/xdg:${XDG_CONFIG_DIRS:-/etc/xdg}" ;; esac
case ":${XDG_DATA_DIRS:-}:" in *":$q/share:"*) ;; *) export XDG_DATA_DIRS="$q/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" ;; esac
p="${1:-$HOME}"
case "$p" in file://*) p=$(printf '%s' "${p#file://}" | sed 's/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g' | xargs -0 printf '%b') ;; esac
case "${LANG:-en}" in en*|C*|POSIX*) export LANGUAGE="en@macshell:${LANGUAGE:-en_US}" ;; esac
set --
[ -f "$p" ] && set -- --select
qss="$HOME/.config/hypr-macshell/qt/finder.qss"
[ -f "$qss" ] && set -- -stylesheet "$qss" "$@"
command -v dolphin >/dev/null 2>&1 && exec dolphin "$@" "$p"
for fm in nautilus nemo thunar pcmanfm-qt; do
    command -v "$fm" >/dev/null 2>&1 && exec "$fm" "$p"
done
exec xdg-open "$p"
