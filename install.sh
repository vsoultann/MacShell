#!/usr/bin/env bash
# MacShell (Tahoe edition) installer — macOS 26/27-style desktop shell for Hyprland, built on Quickshell.
#
#   ./install.sh                interactive menu
#   ./install.sh --all          everything below
#   ./install.sh [options]
#
# Options
#   --deps          install dependencies (Arch / CachyOS / EndeavourOS / Manjaro via pacman + paru/yay for AUR)
#   --deps-only     only install dependencies, then exit (used by Settings → General → Install dependencies)
#   --shell         install / update the shell itself (menu bar, Dock, widgets, Spotlight, lock screen)
#   --session       add "Hyprland (MacShell)" as a SEPARATE login session (own config, your Hyprland untouched; needs sudo)
#   --existing      instead of a separate session, start MacShell from your CURRENT Hyprland config
#   --icons         install the MacTahoe icon theme (Apple-style app icons)
#   --fonts         install Inter + Roboto Flex (the lock screen's stretch clock)
#   --apply         set the icon theme + font for GTK / Qt / KDE apps
#   --wallpapers    download the macOS 27 "Golden Gate" light + dark wallpapers
#   --sounds        generate the UI sound effects
#   --uninstall     remove MacShell (your settings in ~/.config/macbar, macdock, macshell are kept)
#   -y, --yes       don't ask questions (for --all / scripts)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS="$HOME/.config/quickshell"
SESS="$HOME/.config/hypr-macshell"
SHARE="$HOME/.local/share/macshell"
YES=0

c_b=$'\e[1m'; c_d=$'\e[2m'; c_g=$'\e[32m'; c_y=$'\e[33m'; c_r=$'\e[31m'; c_0=$'\e[0m'
say()  { printf '%s==>%s %s\n' "$c_g$c_b" "$c_0" "$*"; }
note() { printf '%s  ·%s %s\n' "$c_d" "$c_0" "$*"; }
warn() { printf '%s!!%s %s\n' "$c_y$c_b" "$c_0" "$*"; }
die()  { printf '%sxx%s %s\n' "$c_r$c_b" "$c_0" "$*" >&2; exit 1; }
ask()  { [ "$YES" = 1 ] && return 0; local a; read -r -p "$1 [Y/n] " a; [ -z "$a" ] || [[ "$a" =~ ^[Yy] ]]; }
have() { command -v "$1" >/dev/null 2>&1; }

PKGS=(quickshell qt6-shadertools qt6-multimedia qt6-svg jq curl git ffmpeg imagemagick libnotify grim slurp wl-clipboard cliphist
      playerctl brightnessctl bluez-utils networkmanager power-profiles-daemon hypridle hyprlock hyprsunset wf-recorder
      mpvpaper awww inter-font noto-fonts-emoji python-numpy zenity openbsd-netcat libwebp)

do_deps() {
    say "Installing dependencies"
    if ! have pacman; then
        warn "Not an Arch-based system. Install these with your package manager:"
        printf '    %s\n' "${PKGS[@]}"
        return 0
    fi
    local repo=() aur=()
    for p in "${PKGS[@]}"; do
        if pacman -Si "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
    done
    [ ${#repo[@]} -gt 0 ] && sudo pacman -S --needed --noconfirm "${repo[@]}"
    if [ ${#aur[@]} -gt 0 ]; then
        local helper=""; have paru && helper=paru; [ -z "$helper" ] && have yay && helper=yay
        if [ -n "$helper" ]; then "$helper" -S --needed --noconfirm "${aur[@]}"
        else warn "These come from the AUR; install paru or yay, then: ${aur[*]}"; fi
    fi
    # a Quickshell built against an older Qt crashes; the repo package is rebuilt with Qt
    if have qs && qs --version 2>&1 | grep -q 'built against'; then warn "Quickshell was built against an older Qt — reinstall it (sudo pacman -S quickshell)"; fi
}

compile_shaders() {
    local qsb=/usr/lib/qt6/bin/qsb
    [ -x "$qsb" ] || qsb=$(command -v qsb || true)
    [ -n "$qsb" ] || { warn "qsb (qt6-shadertools) not found: the Liquid Glass shaders compile on first launch instead"; return 0; }
    for f in "$1"/*.frag; do [ -f "$f" ] && "$qsb" --qt6 -o "$f.qsb" "$f" >/dev/null 2>&1 || true; done
}

do_shell() {
    say "Installing the shell"
    mkdir -p "$QS/MacShell" "$QS/MacLock" "$SHARE"
    # shell (repo root) — QML, shaders, assets
    rsync -a --delete --exclude '.git' --exclude 'MacLock' --exclude 'session' --exclude 'install.sh' --exclude 'README*' \
          --exclude '*.qsb' "$REPO"/ "$QS/MacShell"/
    rsync -a --delete --exclude '*.qsb' "$REPO/MacLock"/ "$QS/MacLock"/
    compile_shaders "$QS/MacShell"; compile_shaders "$QS/MacLock"
    # session config + scripts (your custom/ overrides are never overwritten)
    mkdir -p "$SESS"
    rsync -a --exclude 'custom/' "$REPO/session"/ "$SESS"/
    [ -d "$SESS/custom" ] || cp -r "$REPO/session/custom" "$SESS/custom"
    find "$SESS" -type f \( -name '*.conf' -o -name '*.lua' -o -name '*.sh' \) -exec sed -i "s|@HOME@|$HOME|g" {} +
    chmod +x "$SESS"/scripts/*.sh "$SESS"/hyprland/scripts/*.sh 2>/dev/null || true
    cp "$REPO/install.sh" "$SHARE/install.sh"; chmod +x "$SHARE/install.sh"
    note "shell: $QS/MacShell   lock screen: $QS/MacLock   session config: $SESS"
}

do_session() {
    say "Adding the \"Hyprland (MacShell)\" login session"
    sudo sh "$SESS/install-sddm-session.sh"
    note "Pick \"Hyprland (MacShell)\" on your login screen. Your normal Hyprland session is untouched."
}

do_existing() {
    say "Starting MacShell from your current Hyprland config"
    local hc="$HOME/.config/hypr"
    if [ -f "$hc/hyprland.lua" ]; then
        local f="$hc/macshell.lua"
        cat > "$f" <<EOF
-- MacShell (added by install.sh)
hl.on("hyprland.start", function ()
    hl.exec_cmd("$SESS/scripts/macshell-wallpaper.sh")
    hl.exec_cmd("sh -c 'while :; do pkill -x mako; qs -c MacShell; sleep 1; done'")
    hl.exec_cmd("hypridle -c $SESS/hypridle.conf")
end)
EOF
        grep -q 'require("macshell")' "$hc/hyprland.lua" || printf '\nrequire("macshell")\n' >> "$hc/hyprland.lua"
        note "added $f and require(\"macshell\") to hyprland.lua"
    elif [ -f "$hc/hyprland.conf" ]; then
        local f="$hc/macshell.conf"
        cat > "$f" <<EOF
# MacShell (added by install.sh)
exec-once = $SESS/scripts/macshell-wallpaper.sh
exec-once = sh -c 'while :; do pkill -x mako; qs -c MacShell; sleep 1; done'
exec-once = hypridle -c $SESS/hypridle.conf
layerrule = blur, macbarbg
layerrule = ignorealpha 0.05, macbarbg
layerrule = blur, macdock
layerrule = noanim, ^(macspot|macbar|macbarbg|macdock|macshot|macwidgets)\$
bind = SUPER, L, exec, loginctl lock-session
EOF
        grep -q 'macshell.conf' "$hc/hyprland.conf" || printf '\nsource = %s\n' "$f" >> "$hc/hyprland.conf"
        note "added $f and sourced it from hyprland.conf"
    else
        die "no ~/.config/hypr/hyprland.conf or hyprland.lua found"
    fi
    warn "Stop any other bar / notification daemon you start yourself (waybar, mako, swaync…) so they don't fight MacShell."
}

do_icons() {
    say "Installing the MacTahoe icon theme"
    local t; t=$(mktemp -d)
    git clone --depth 1 https://github.com/vinceliuice/MacTahoe-icon-theme.git "$t/icons" >/dev/null 2>&1 || die "couldn't download MacTahoe"
    (cd "$t/icons" && ./install.sh >/dev/null)
    rm -rf "$t"
}

do_fonts() {
    say "Installing fonts (Inter, Roboto Flex)"
    have pacman && { pacman -Q inter-font >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm inter-font; }
    mkdir -p "$HOME/.local/share/fonts/RobotoFlex"
    curl -fsSL -o "$HOME/.local/share/fonts/RobotoFlex/RobotoFlex.ttf" \
        "https://github.com/google/fonts/raw/main/ofl/robotoflex/RobotoFlex%5BGRAD,XOPQ,XTRA,YOPQ,YTAS,YTDE,YTFI,YTLC,YTUC,opsz,slnt,wdth,wght%5D.ttf"
    curl -fsSL -o "$HOME/.local/share/fonts/RobotoFlex/OFL.txt" https://github.com/google/fonts/raw/main/ofl/robotoflex/OFL.txt
    fc-cache -f >/dev/null 2>&1 || true
}

do_apply() {
    say "Applying the icon theme + font"
    local icons=MacTahoe-dark
    have gsettings && { gsettings set org.gnome.desktop.interface icon-theme "$icons" || true; gsettings set org.gnome.desktop.interface font-name "Inter 11" || true; }
    have kwriteconfig6 && { kwriteconfig6 --file kdeglobals --group Icons --key Theme "$icons"; kwriteconfig6 --file kdeglobals --group General --key font "Inter,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"; }
    for f in "$HOME/.config/qt6ct/qt6ct.conf" "$HOME/.config/qt5ct/qt5ct.conf"; do [ -f "$f" ] && sed -i "s/^icon_theme=.*/icon_theme=$icons/" "$f"; done
    for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
        [ -f "$f" ] && sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$icons/; s/^gtk-font-name=.*/gtk-font-name=Inter 11/" "$f"
    done
}

do_wallpapers() {
    say "Downloading the macOS 27 Golden Gate wallpapers"
    local d="$HOME/Pictures/Wallpapers"; mkdir -p "$d"
    curl -fsSL -A 'Mozilla/5.0' -o "$d/macos-27-GoldenGate-Dark.png"  https://9to5mac.com/wp-content/uploads/sites/6/2026/06/Gold-Gate-wallpaper-dark.png || warn "dark version failed"
    curl -fsSL -A 'Mozilla/5.0' -o "$d/macos-27-GoldenGate-Light.png" https://9to5mac.com/wp-content/uploads/sites/6/2026/06/Gold-Gate-wallpaper.png || warn "light version failed"
    note "Apple's wallpapers are Apple's: they're downloaded from the web, not shipped in this repo."
    mkdir -p "$HOME/.config/macbar"
    [ -s "$HOME/.config/macbar/settings.json" ] || printf '{ "wallpaperPath": "%s" }\n' "$d/macos-27-GoldenGate-Dark.png" > "$HOME/.config/macbar/settings.json"
}

do_sounds() {
    say "Generating UI sounds"
    python3 "$SESS/scripts/macshell-make-sounds.py" || warn "needs python-numpy"
}

do_uninstall() {
    say "Removing MacShell"
    pkill -f 'qs -c MacShell' 2>/dev/null || true
    rm -rf "$QS/MacShell" "$QS/MacLock" "$SHARE"
    rm -f "$HOME/.config/hypr/macshell.conf" "$HOME/.config/hypr/macshell.lua"
    sed -i '/macshell.conf/d' "$HOME/.config/hypr/hyprland.conf" 2>/dev/null || true
    sed -i '/require("macshell")/d' "$HOME/.config/hypr/hyprland.lua" 2>/dev/null || true
    if [ -f /usr/share/wayland-sessions/hyprland-macshell.desktop ] && ask "Remove the login session too (sudo)?"; then
        sudo rm -f /usr/share/wayland-sessions/hyprland-macshell.desktop /usr/local/bin/start-hyprland-macshell
    fi
    note "kept: $SESS and your settings (~/.config/macbar, ~/.config/macdock, ~/.config/macshell). Delete them yourself for a clean slate."
}

menu() {
    printf '\n%s  MacShell — Tahoe edition%s\n%s  macOS 26/27-style shell for Hyprland%s\n\n' "$c_b" "$c_0" "$c_d" "$c_0"
    local o=()
    ask "Install dependencies?" && o+=(deps)
    o+=(shell)
    printf '\nHow should MacShell start?\n  1) as its own login session "Hyprland (MacShell)" (recommended, leaves your Hyprland alone)\n  2) inside my current Hyprland config\n  3) don'"'"'t set it up to start\n'
    local w; read -r -p "Choose [1]: " w; case "${w:-1}" in 1) o+=(session) ;; 2) o+=(existing) ;; esac
    ask "Install the MacTahoe icon theme?" && o+=(icons)
    ask "Install the fonts (Inter, Roboto Flex)?" && o+=(fonts)
    ask "Apply the icons + font to your apps?" && o+=(apply)
    ask "Download the macOS 27 Golden Gate wallpapers?" && o+=(wallpapers)
    o+=(sounds)
    run "${o[@]}"
}

run() {
    local s
    for s in deps shell session existing icons fonts apply wallpapers sounds; do
        for want in "$@"; do [ "$want" = "$s" ] && "do_$s"; done
    done
    say "Done. Log into \"Hyprland (MacShell)\" (or restart Hyprland). Settings: Apple menu → System Settings…"
}

[ $# -eq 0 ] && { menu; exit 0; }
todo=()
for a in "$@"; do
    case "$a" in
        -y|--yes) YES=1 ;;
        --all) todo+=(deps shell session icons fonts apply wallpapers sounds) ;;
        --deps-only) do_deps; exit 0 ;;
        --deps|--shell|--session|--existing|--icons|--fonts|--apply|--wallpapers|--sounds) todo+=("${a#--}") ;;
        --uninstall) do_uninstall; exit 0 ;;
        -h|--help) sed -n '2,23p' "$0"; exit 0 ;;
        *) die "unknown option: $a (see --help)" ;;
    esac
done
run "${todo[@]}"
