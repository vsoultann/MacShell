#!/bin/sh
# VLC in MacShell: still VLC, dressed like the rest of the session (the MacShell Kvantum theme, light / dark and
# the accent from macshell-kde-theme.sh, Inter), the MacShell session only.
#   macshell-vlc.sh [vlc arguments …]
q="$HOME/.config/hypr-macshell/qt"
# VLC is a Qt 5 app: it needs Kvantum's Qt 5 half (Arch: kvantum-qt5). A copy kept with MacShell is used when
# the package isn't there.
if [ ! -f /usr/lib/qt/plugins/styles/libkvantum.so ] && [ -f "$HOME/.local/share/macshell/qt5-plugins/styles/libkvantum.so" ]; then
    export QT_PLUGIN_PATH="$HOME/.local/share/macshell/qt5-plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
fi
if [ -f /usr/lib/qt/plugins/styles/libkvantum.so ] || [ -n "${QT_PLUGIN_PATH:-}" ]; then
    export QT_STYLE_OVERRIDE=kvantum
    # no Qt 5 KDE platform theme here: Kvantum's own palette is the one to use
    export QT_QPA_PLATFORMTHEME=
fi
# Inter for VLC's text: a font config of its own that reads the system's (and yours) and then prefers Inter
cat > "$q/vlc-fonts.conf" <<'XML'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
  <alias binding="strong"><family>sans-serif</family><prefer><family>Inter</family></prefer></alias>
</fontconfig>
XML
export FONTCONFIG_FILE="$q/vlc-fonts.conf"
# the volume wedge is VLC's own drawing: give it the accent instead of its green
hex=$(cat "$q/accent" 2>/dev/null || echo 0a84ff)
r=$((0x$(printf '%s' "$hex" | cut -c1-2))); g=$((0x$(printf '%s' "$hex" | cut -c3-4))); b=$((0x$(printf '%s' "$hex" | cut -c5-6)))
c="$r;$g;$b"
exec vlc --qt-slider-colours="$c;$c;$c;$c" "$@"
