#!/bin/sh
# Dresses KDE / Qt apps (Finder = Dolphin first of all) like macOS, in the MacShell session only.
#
#   macshell-kde-theme.sh light|dark [icon-theme] [glass|solid]
#
# The session puts ~/.config/hypr-macshell/qt/xdg at the front of XDG_CONFIG_DIRS. The kdeglobals and dolphinrc
# written there lock their keys ([$i], KDE's kiosk mark), so they win over your own ~/.config/kdeglobals and
# dolphinrc here, and your other sessions, which never read this folder, keep exactly what they had.
# MacShell runs this at login and whenever it switches between light and dark.
mode="${1:-dark}"
icons="${2:-}"
# glass: windows are translucent and the compositor blurs what is behind them, live (the glass materials);
# solid: Opaque and Game Mode, where MacShell switches compositor blur off and nothing may show through
look="${3:-glass}"
Q="$HOME/.config/hypr-macshell/qt"
X="$Q/xdg"
mkdir -p "$X"

case "$mode" in
    light) scheme=MacTahoeLight; style=kvantum;      [ -n "$icons" ] || icons=MacTahoe-light ;;
    *)     scheme=MacTahoeDark;  style=kvantum-dark; [ -n "$icons" ] || icons=MacTahoe-dark ;;
esac
colors="$Q/share/color-schemes/$scheme.colors"
font="Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"

tmp="$X/kdeglobals.tmp"
{
    printf '# written by macshell-kde-theme.sh (%s) — MacShell session only\n' "$mode"
    printf '[General]\nColorScheme[$i]=%s\nfont[$i]=%s\nmenuFont[$i]=%s\ntoolBarFont[$i]=%s\nsmallestReadableFont[$i]=%s\n\n' \
        "$scheme" "$font" "$font" "$font" "Inter,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    printf '[KDE]\nwidgetStyle[$i]=%s\n\n' "$style"
    printf '[Icons]\nTheme[$i]=%s\n\n' "$icons"
    # every colour group of the scheme, locked whole
    if [ -f "$colors" ]; then
        awk '/^\[/ { g = $0; sub(/^\[/, "", g); sub(/\].*$/, "", g); keep = (g ~ /^Colors:/ || g == "WM"); if (keep) print "[" g "][$i]"; next }
             keep { print }' "$colors"
    fi
} > "$tmp" && mv "$tmp" "$X/kdeglobals"

# Dolphin as Finder: its own colour scheme and fonts (which beat kdeglobals) follow the shell, no menu bar
# (the toolbar has the … menu), the folder's name as the title, one view for every folder like Finder
tmp="$X/dolphinrc.tmp"
cat > "$tmp" <<EOF
# written by macshell-kde-theme.sh ($mode) — MacShell session only
[UiSettings]
ColorScheme[\$i]=$scheme

[MainWindow]
MenuBar[\$i]=Disabled
ToolBarsMovable[\$i]=Disabled

[General]
ShowFullPath[\$i]=false
ShowZoomSlider[\$i]=false
ShowSpaceInfo[\$i]=false

[IconsMode]
UseSystemFont[\$i]=true

[CompactMode]
UseSystemFont[\$i]=true

[DetailsMode]
UseSystemFont[\$i]=true
EOF
mv "$tmp" "$X/dolphinrc"

# The Kvantum theme both styles draw with: MacShell's own copy of MacTahoe (kvantum = MacShell, kvantum-dark = its
# MacShellDark half), translucent or solid to match the shell. Only apps styled with Kvantum read it, and only the
# MacShell session styles apps with it; the MacTahoe copy itself is never touched.
src="$Q/kvantum/MacTahoe"
[ -d "$src" ] || src="$HOME/.config/Kvantum/MacTahoe"
kv="$HOME/.config/Kvantum/MacShell"
if [ -f "$src/MacTahoe.kvconfig" ]; then
    mkdir -p "$kv"
    if [ "$look" = solid ]; then t=false; else t=true; fi
    for v in "" Dark; do
        cp -f "$src/MacTahoe$v.svg" "$kv/MacShell$v.svg"
        sed -e "s/^translucent_windows=.*/translucent_windows=$t/" -e "s/^blurring=.*/blurring=$t/" \
            -e "s/^popup_blurring=.*/popup_blurring=$t/" "$src/MacTahoe$v.kvconfig" > "$kv/MacShell$v.kvconfig"
    done
    k="$HOME/.config/Kvantum/kvantum.kvconfig"
    if [ -f "$k" ] && grep -q '^theme=' "$k"; then sed -i 's/^theme=.*/theme=MacShell/' "$k"
    else printf '[General]\ntheme=MacShell\n' >> "$k"; fi
fi

# tell running KDE apps: colours and icons changed (only apps in this session listen on this bus). Not "style
# changed": Dolphin rebuilds its style on it and drops Finder's toolbar stylesheet (the room for the lights) with it;
# new Finder windows pick up the other style half anyway.
if command -v dbus-send >/dev/null 2>&1; then
    for t in 0 4; do
        dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:$t int32:0 2>/dev/null
    done
fi
exit 0
