#!/bin/sh
# Dresses KDE / Qt apps (Finder = Dolphin first of all) like macOS, in the MacShell session only.
#
#   macshell-kde-theme.sh light|dark [icon-theme] [glass|solid] [accent #rrggbb]
#
# The session puts ~/.config/hypr-macshell/qt/xdg at the front of XDG_CONFIG_DIRS. The kdeglobals and dolphinrc
# written there lock their keys ([$i], KDE's kiosk mark), so they win over your own ~/.config/kdeglobals and
# dolphinrc here, and your other sessions, which never read this folder, keep exactly what they had.
# MacShell runs this at login and whenever light / dark, the material, the icons or the accent colour change.
mode="${1:-dark}"
icons="${2:-}"
# glass: windows are translucent and the compositor blurs what is behind them, live (the glass materials);
# solid: Opaque and Game Mode, where MacShell switches compositor blur off and nothing may show through
look="${3:-glass}"
accent="${4:-#0a84ff}"
Q="$HOME/.config/hypr-macshell/qt"
X="$Q/xdg"
mkdir -p "$X"

case "$mode" in
    light) scheme=MacTahoeLight; kvtheme=MacShell;     [ -n "$icons" ] || icons=MacTahoe-light ;;
    *)     scheme=MacTahoeDark;  kvtheme=MacShellDark; [ -n "$icons" ] || icons=MacTahoe-dark ;;
esac
colors="$Q/share/color-schemes/$scheme.colors"
font="Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"

# the accent as r,g,b (KDE's colour format) and #rrggbb, plus a deeper shade for pressed / outlined parts
hex=$(printf '%s' "$accent" | tr -d '#' | tr 'A-F' 'a-f')
[ ${#hex} -eq 8 ] && hex=${hex#??}                  # #aarrggbb from Qt
case "$hex" in [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;; *) hex=0a84ff ;; esac
r=$((0x$(printf '%s' "$hex" | cut -c1-2))); g=$((0x$(printf '%s' "$hex" | cut -c3-4))); b=$((0x$(printf '%s' "$hex" | cut -c5-6)))
rgb="$r,$g,$b"
deep=$(printf '%02x%02x%02x' $((r * 82 / 100)) $((g * 82 / 100)) $((b * 82 / 100)))

tmp="$X/kdeglobals.tmp"
{
    printf '# written by macshell-kde-theme.sh (%s, accent #%s) — MacShell session only\n' "$mode" "$hex"
    printf '[General]\nColorScheme[$i]=%s\nAccentColor[$i]=%s\nfont[$i]=%s\nmenuFont[$i]=%s\ntoolBarFont[$i]=%s\nsmallestReadableFont[$i]=%s\n\n' \
        "$scheme" "$rgb" "$font" "$font" "$font" "Inter,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    # Finder opens with a double click
    # one style name for light and dark: the theme it draws with is picked below (Qt 5 apps such as VLC only
    # know "kvantum", so switching the theme rather than the style is what lets them follow light / dark too)
    printf '[KDE]\nwidgetStyle[$i]=kvantum\nSingleClick[$i]=false\n\n'
    printf '[Icons]\nTheme[$i]=%s\n\n' "$icons"
    # every colour group of the scheme, locked whole, with the shell's accent for selection and focus
    if [ -f "$colors" ]; then
        awk -v acc="$rgb" '
            /^\[/ { g = $0; sub(/^\[/, "", g); sub(/\].*$/, "", g); keep = (g ~ /^Colors:/ || g == "WM"); if (keep) print "[" g "][$i]"; next }
            !keep { next }
            g == "Colors:Selection" && /^(BackgroundNormal|BackgroundAlternate|DecorationFocus|DecorationHover)=/ { sub(/=.*/, "=" acc); print; next }
            /^(DecorationFocus|DecorationHover)=/ { sub(/=.*/, "=" acc); print; next }
            g == "WM" && /^activeBackground=/ { print; next }
            { print }' "$colors"
    fi
} > "$tmp" && mv "$tmp" "$X/kdeglobals"

# Dolphin as Finder. Its own colour scheme and fonts (which beat kdeglobals) follow the shell; no menu bar (the
# toolbar has the … menu), no status bar, no tab strip unless you open a second tab, a fresh window every time,
# the folder's name as the title, Finder's icon sizes (64 px icons, 16 px in the list and the sidebar), no
# selection "+" on icons, folders that unfold in the list like Finder's disclosure triangles.
tmp="$X/dolphinrc.tmp"
cat > "$tmp" <<EOF
# written by macshell-kde-theme.sh ($mode) — MacShell session only
[UiSettings]
ColorScheme[\$i]=$scheme

[MainWindow]
MenuBar[\$i]=Disabled
ToolBarsMovable[\$i]=Disabled

[MainWindow][Toolbar mainToolBar]
ToolButtonStyle[\$i]=IconOnly
IconSize[\$i]=16

[General]
ShowFullPath[\$i]=false
ShowZoomSlider[\$i]=false
ShowSpaceInfo[\$i]=false
ShowStatusBar[\$i]=Disabled
RememberOpenedTabs[\$i]=false
ShowSelectionToggle[\$i]=false
GlobalViewProps[\$i]=true
ConfirmClosingMultipleTabs[\$i]=false

[IconsMode]
UseSystemFont[\$i]=true
IconSize[\$i]=64
PreviewSize[\$i]=64
MaximumTextLines[\$i]=2

[CompactMode]
UseSystemFont[\$i]=true
PreviewSize[\$i]=16

[DetailsMode]
UseSystemFont[\$i]=true
PreviewSize[\$i]=16
ExpandableFolders[\$i]=true

[PlacesPanel]
IconSize[\$i]=16
EOF
mv "$tmp" "$X/dolphinrc"

# Finder's sidebar names: Favorites, Locations, Network… KDE reads them from its translations, so the session has
# a small English one of its own (macshell-finder.sh starts Dolphin with LANGUAGE=en@macshell:…, which falls
# back to plain English for everything else). Home is your name, like on a Mac.
if command -v msgfmt >/dev/null 2>&1; then
    loc="$Q/share/locale/en@macshell/LC_MESSAGES"
    mkdir -p "$loc"
    who=$(id -un 2>/dev/null || echo Home)
    cat > "$loc/kio6.po" <<EOF
msgid ""
msgstr ""
"Content-Type: text/plain; charset=UTF-8\\n"
"Language: en\\n"

msgctxt "@item"
msgid "Places"
msgstr "Favorites"

msgctxt "@item"
msgid "Devices"
msgstr "Locations"

msgctxt "@item"
msgid "Removable Devices"
msgstr "Locations"

msgctxt "@item"
msgid "Remote"
msgstr "Network"

msgctxt "@item"
msgid "Search For"
msgstr "Smart Folders"

msgctxt "@item The place group section name for recent dynamic lists"
msgid "Recent"
msgstr "Recents"

msgctxt "KFile System Bookmarks"
msgid "Home"
msgstr "$who"
EOF
    msgfmt -o "$loc/kio6.mo" "$loc/kio6.po" 2>/dev/null
fi

# The Kvantum themes: MacShell (light) and MacShellDark, MacShell's own copies of MacTahoe's two halves,
# translucent or solid to match the shell, MacTahoe's blues repainted in the accent (and the highlight colour
# itself), toolbar buttons that sit together grouped like Finder's, overlay scrollbars, solid menus (nothing blurs
# behind an app's menus, so a see-through one would just be a painted imitation of glass), and a selected item that
# is the accent with white text in the window you are using (grey in a background one: Kvantum "pressed" =
# selected + active, "toggled" = not). Only apps styled with Kvantum read them, and only the MacShell session
# styles apps with Kvantum; the MacTahoe copy itself is never touched.
src="$Q/kvantum/MacTahoe"
[ -d "$src" ] || src="$HOME/.config/Kvantum/MacTahoe"
if [ -f "$src/MacTahoe.kvconfig" ]; then
    if [ "$look" = solid ]; then t=false; else t=true; fi
    rm -f "$HOME/.config/Kvantum/MacShell/MacShellDark".* 2>/dev/null      # (the dark half used to live in here)
    for v in "" Dark; do
        kv="$HOME/.config/Kvantum/MacShell$v"
        mkdir -p "$kv"
        sed -e "s/#0860f2/#$hex/gI" -e "s/#315bef/#$hex/gI" -e "s/#5294e2/#$hex/gI" \
            -e "s/#195edc/#$deep/gI" -e "s/#195dda/#$deep/gI" "$src/MacTahoe$v.svg" > "$kv/MacShell$v.svg"
        sed -e "s/^translucent_windows=.*/translucent_windows=$t/" -e "s/^blurring=.*/blurring=$t/" \
            -e "s/^popup_blurring=.*/popup_blurring=$t/" -e "s/^group_toolbar_buttons=.*/group_toolbar_buttons=true/" \
            -e "s/^transient_scrollbar=.*/transient_scrollbar=true/" -e "s/^reduce_menu_opacity=.*/reduce_menu_opacity=0/" \
            -e "s/^highlight.color=.*/highlight.color=#$hex/" -e "s/^inactive.highlight.color=.*/inactive.highlight.color=#$hex/" \
            -e "s/^highlight.text.color=.*/highlight.text.color=#ffffff/" \
            "$src/MacTahoe$v.kvconfig" > "$kv/MacShell$v.kvconfig"
        python3 -I - "$kv/MacShell$v.svg" "$hex" <<'PY' 2>/dev/null
import re, sys
p, hexc = sys.argv[1], sys.argv[2]
s = open(p).read()
def fix(m):
    t = m.group(0)
    t = re.sub(r"fill:#[0-9a-fA-F]{6}", "fill:#" + hexc, t)
    t = re.sub(r'fill="#[0-9a-fA-F]{6}"', 'fill="#' + hexc + '"', t)
    return re.sub(r"((?:fill-)?opacity:)[0-9.]+", r"\g<1>1", t)
s = re.sub(r'<(?:rect|path)[^>]*id="itemview-pressed[^"]*"[^>]*>', fix, s)
open(p, "w").write(s)
PY
        sed -i '/^\[ItemView\]/,/^\[/{s/^text.press.color=.*/text.press.color=#ffffff/;s/^highlight.text.color=.*/highlight.text.color=#ffffff/}' "$kv/MacShell$v.kvconfig"
    done
    k="$HOME/.config/Kvantum/kvantum.kvconfig"
    if [ -f "$k" ] && grep -q '^theme=' "$k"; then sed -i "s/^theme=.*/theme=$kvtheme/" "$k"
    else printf '[General]\ntheme=%s\n' "$kvtheme" >> "$k"; fi
fi

# VLC: dressed by the same theme (Kvantum's Qt 5 half, through macshell-vlc.sh) but still VLC. The session's
# vlc.desktop is the system one with only the command changed, so its name, icon and file types stay VLC's own.
if [ -f /usr/share/applications/vlc.desktop ]; then
    mkdir -p "$Q/share/applications"
    sed -e "s|^Exec=/usr/bin/vlc|Exec=$HOME/.config/hypr-macshell/scripts/macshell-vlc.sh|" \
        -e "s|^Exec=vlc|Exec=$HOME/.config/hypr-macshell/scripts/macshell-vlc.sh|" \
        /usr/share/applications/vlc.desktop > "$Q/share/applications/vlc.desktop"
fi
printf '%s\n' "$hex" > "$Q/accent"

# tell running KDE apps: colours and icons changed (only apps in this session listen on this bus). Not "style
# changed": Dolphin rebuilds its style on it and drops Finder's stylesheet with it; new Finder windows pick up
# the other style half anyway.
if command -v dbus-send >/dev/null 2>&1; then
    for t in 0 4; do
        dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:$t int32:0 2>/dev/null
    done
fi
exit 0
