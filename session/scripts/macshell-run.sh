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
# stderr of the last runs (Qt / Wayland fatal errors never reach the shell's own log)
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

    [ -f "$LOGDIR/qs-stderr.log" ] && mv -f "$LOGDIR/qs-stderr.log" "$LOGDIR/qs-stderr.prev.log"
    qs -c "$name" 2>"$LOGDIR/qs-stderr.log"
    echo "exit status $? after $(( $(date +%s) - start ))s" >>"$LOGDIR/qs-stderr.log"
    lived=$(( $(date +%s) - start ))
    if [ "$lived" -lt 15 ]; then fails=$((fails + 1)); else fails=0; fi
    # after the fallback has been running, try the real one again next time
    [ "$name" = "$GOOD" ] && fails=0
    sleep 1
done
