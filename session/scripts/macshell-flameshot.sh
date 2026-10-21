#!/bin/sh
# Screenshots with Flameshot, the MacShell way.
#
#   macshell-flameshot.sh gui | full … | screen …     (Flameshot's own arguments)
#   macshell-flameshot.sh --check                       exit 0 when Flameshot is installed
#
# - a Flameshot in ~/.local/bin (your own build) wins over the system one: Hyprland's PATH doesn't include it
# - Breeze style: under the session's Kvantum style Flameshot crashes when its windows close
# - no Flameshot at all: MacShell's own screenshot tool takes the shot instead
fs="$HOME/.local/bin/flameshot"
[ -x "$fs" ] || fs=$(command -v flameshot 2>/dev/null) || fs=""
if [ "$1" = "--check" ]; then [ -n "$fs" ]; exit; fi
if [ -z "$fs" ]; then
    case "$1" in
        gui)  exec qs -c "${MACSHELL_CONFIG:-MacShell}" ipc call screenshot region ;;
        full) exec qs -c "${MACSHELL_CONFIG:-MacShell}" ipc call screenshot screen ;;
    esac
    exit 127
fi
QT_STYLE_OVERRIDE=Breeze exec "$fs" "$@"
