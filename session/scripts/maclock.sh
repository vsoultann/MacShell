#!/bin/sh
# Lock the session with MacLock (~/.config/quickshell/MacLock). Called by hypridle's lock_cmd.
# One locker at a time. If it crashes while locked, start it again: Hyprland keeps the session locked and
# misc:allow_session_lock_restore lets the new instance take over. After 5 crashes in a row, fall back to hyprlock.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/maclock.lock"
flock -n 9 || exit 0
pidof hyprlock >/dev/null && exit 0
# the lock plays the animated wallpaper with Qt Multimedia: decode it on the Intel iGPU (VA-API), never wake the NVIDIA dGPU
export QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi
# the desktop's animated wallpaper is hidden while locked: stop decoding it (MacLock plays its own copy)
"$HOME/.config/hypr-macshell/scripts/macshell-wallpause.sh" all pause
trap '"$HOME/.config/hypr-macshell/scripts/macshell-wallpause.sh" all resume' EXIT
n=0
while [ "$n" -lt 5 ]; do
    qs -c MacLock && exit 0
    n=$((n + 1))
    sleep 0.3
done
exec hyprlock
