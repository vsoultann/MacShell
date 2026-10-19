#!/bin/sh
# Keeps MacShell running, and never leaves you with an empty desktop.
#
# A shell that crashes is simply started again. But a config that fails to load (a bad edit, a broken
# update) used to fail on every restart, so the bar and the Dock never came back. Every time MacShell
# starts and stays up, its folder is copied to MacShell.lastgood; if it keeps dying within seconds, the
# last good copy is started instead, so you always get a working desktop back.
CFG="${MACSHELL_CONFIG:-MacShell}"
QS_DIR="$HOME/.config/quickshell"
GOOD="$CFG.lastgood"
export QSG_USE_SIMPLE_ANIMATION_DRIVER=1 MALLOC_ARENA_MAX=2
# videos (Mac Hello, previews) decode on the integrated GPU via VA-API: probing CUDA first woke the NVIDIA card
export QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi
# Everything the shell prints, per run: ~/.cache/macshell/shell.log (this run) and shell.prev.log (the one before).
# Settings → About → Logs opens or copies it. Qt / Wayland fatal errors only ever show up here.
LOGDIR="${XDG_CACHE_HOME:-$HOME/.cache}/macshell"; mkdir -p "$LOGDIR"

fails=0
while :; do
    pkill -x mako 2>/dev/null
    if [ "$fails" -ge 3 ] && [ -d "$QS_DIR/$GOOD" ]; then
        name="$GOOD"
        notify-send -a MacShell "MacShell" "The current setup would not start, so the last working one is running. Fix or update it, then restart the shell." 2>/dev/null &
    else
        name="$CFG"
    fi

    start=$(date +%s)
    # once it has stayed up for a while, this config is good: remember it
    if [ "$name" = "$CFG" ]; then
        ( sleep 20
          if pgrep -f "qs -c $CFG\$" >/dev/null 2>&1; then
              rm -rf "$QS_DIR/$GOOD.tmp"
              cp -a "$QS_DIR/$CFG" "$QS_DIR/$GOOD.tmp" 2>/dev/null &&
                  rm -rf "$QS_DIR/$GOOD" && mv "$QS_DIR/$GOOD.tmp" "$QS_DIR/$GOOD"
          fi ) &
    fi

    [ -f "$LOGDIR/shell.log" ] && mv -f "$LOGDIR/shell.log" "$LOGDIR/shell.prev.log"
    { echo "== MacShell ($name) started $(date '+%F %T')"; } >"$LOGDIR/shell.log"
    # no colour codes in the file; the Wayland text-input chatter is dropped (thousands of harmless lines)
    qs -c "$name" 2>&1 | sed -u -e 's/\x1b\[[0-9;]*m//g' -e '/QWaylandTextInputv3::disableSurface/d' >>"$LOGDIR/shell.log"
    echo "== exited after $(( $(date +%s) - start ))s" >>"$LOGDIR/shell.log"
    lived=$(( $(date +%s) - start ))
    if [ "$lived" -lt 15 ]; then fails=$((fails + 1)); else fails=0; fi
    # after the fallback has been running, try the real one again next time
    [ "$name" = "$GOOD" ] && fails=0
    sleep 1
done
