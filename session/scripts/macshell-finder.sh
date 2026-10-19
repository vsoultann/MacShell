#!/bin/sh
# Opens folders in MacShell's Finder (the default app for inode/directory in this session).
# If the shell isn't running, the first other file manager that is installed opens it instead.
p="${1:-$HOME}"
case "$p" in file://*) p=$(printf '%s' "${p#file://}" | sed 's/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g' | xargs -0 printf '%b') ;; esac
[ -f "$p" ] && p=$(dirname -- "$p")
qs -c MacShell ipc call finder folder "$p" >/dev/null 2>&1 && exit 0
for fm in dolphin nautilus nemo thunar pcmanfm-qt; do
    command -v "$fm" >/dev/null 2>&1 && exec "$fm" "$p"
done
