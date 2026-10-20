#!/bin/sh
# QuickTime Player in MacShell: VLC, in MacShell's QuickTime skin (macshell-quicktime-skin.py draws it).
#   macshell-quicktime.sh [file|url …]
# The skin needs VLC's skin engine (Arch: vlc-gui-skins2); without it VLC opens as itself.
# the session's own KDE look (session/qt): set here too, for whatever started us without the session's environment
q="$HOME/.config/hypr-macshell/qt"
case ":${XDG_CONFIG_DIRS:-}:" in *":$q/xdg:"*) ;; *) export XDG_CONFIG_DIRS="$q/xdg:${XDG_CONFIG_DIRS:-/etc/xdg}" ;; esac
case ":${XDG_DATA_DIRS:-}:" in *":$q/share:"*) ;; *) export XDG_DATA_DIRS="$q/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" ;; esac
skin="$HOME/.local/share/macshell/quicktime"
gen="$HOME/.config/hypr-macshell/scripts/macshell-quicktime-skin.py"
# (re)draw the skin the first time, and after an update changed how it is drawn
if [ ! -f "$skin/theme.xml" ] || [ "$gen" -nt "$skin/theme.xml" ]; then
    python3 -I "$gen" "$skin" >/dev/null 2>&1
fi

engine=""
for d in /usr/lib/vlc/plugins /usr/lib64/vlc/plugins /usr/lib/x86_64-linux-gnu/vlc/plugins; do
    [ -f "$d/gui/libskins2_plugin.so" ] && engine=system
done
# a copy of the engine kept with MacShell, for systems where it can't be installed as a package
if [ -z "$engine" ] && [ -f "$HOME/.local/share/macshell/vlc-plugins/gui/libskins2_plugin.so" ]; then
    export VLC_PLUGIN_PATH="$HOME/.local/share/macshell/vlc-plugins"
    engine=local
fi

if [ -n "$engine" ] && [ -f "$skin/theme.xml" ]; then
    # the skin engine draws with X11, so VLC runs through XWayland here; the watcher keeps full screen clean
    vlc -I skins2 --skins2-last="$skin/theme.xml" --skins2-transparency --no-video-title-show "$@" &
    pid=$!
    python3 -I "$HOME/.config/hypr-macshell/scripts/macshell-quicktime-watch.py" "$pid" >/dev/null 2>&1 &
    wait "$pid"
    exit $?
fi
exec vlc "$@"
