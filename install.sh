#!/usr/bin/env bash
# MacShell (Tahoe edition) installer — macOS 26/27-style desktop shell for Hyprland, built on Quickshell.
#
#   ./install.sh                       interactive: pick Install / Update / Check / Uninstall, then tick the features
#   ./install.sh --all                 install everything
#   ./install.sh --only shell,lock     install / update just these features
#   ./install.sh --update [features]   pull the latest version, then update the features you name (default: shell,lock,config)
#
# Features — pick only what you want, e.g.  ./install.sh --only spotlight,widgets
#   shell       the shell files + System Settings (every part below needs these; added automatically)
#   menubar     the menu bar          spotlight   Spotlight          controlcenter  Control Center
#   notifications  banners + Notification Center                     dock           the Dock
#   widgets     desktop widgets       clock       the Clock app
#   applemusic  Apple Music (Cider, an Apple Music client by the Cider Collective)
#   (parts you leave out are switched off, so only what you picked runs)
#   lock        the lock screen (MacLock)
#   config      the Hyprland session config + helper scripts (wallpapers, Game Mode, lock); your custom/ files are kept
#   session     add "Hyprland (MacShell)" as a SEPARATE login session (your own Hyprland is untouched; needs sudo)
#   existing    instead of a separate session, start MacShell from your CURRENT Hyprland config
#   deps        dependencies (Arch / CachyOS / EndeavourOS / Manjaro via pacman + paru/yay for AUR)
#   icons       the MacTahoe icon theme (Apple-style app icons)
#   fonts       Inter, Roboto Flex, Nunito and Noto Serif Display (the lock screen clock styles)
#   apply       set the icon theme + font for GTK / Qt / KDE apps
#   wallpapers  the macOS 27 "Golden Gate" light + dark wallpapers
#   sounds      the UI sound effects (+ the Clock's alarm / timer tones)
#
# Every feature is also an option on its own:  --shell  --lock  --config  --session  --deps  --icons  …
# Other options
#   --deps-only     only install dependencies, then exit (used by Settings → General → Install dependencies)
#   --check         show what's installed and what's missing; changes nothing
#   --uninstall [features]   remove everything, or just the features you name (your settings are kept)
#   -y, --yes       don't ask questions
#   -h, --help      this help
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS="$HOME/.config/quickshell"
SESS="$HOME/.config/hypr-macshell"
SHARE="$HOME/.local/share/macshell"
YES=0
ORDER=(deps shell applemusic menubar spotlight controlcenter notifications dock widgets clock lock config session existing icons fonts apply defaults emoji wallpapers sounds)
# the parts of the shell you can pick individually (one set of files, each part switched on or off)
PARTS=(menubar spotlight controlcenter notifications dock widgets clock desktop)
declare -A DESC=(
    [shell]="Shell files + System Settings (needed by every part below)"
    [applemusic]="Apple Music (Cider, by the Cider Collective)"
    [menubar]="Menu bar (Apple menu, app menus, workspaces, tray, clock)"
    [spotlight]="Spotlight (search, clipboard, emoji)"
    [controlcenter]="Control Center"
    [notifications]="Notifications (banners + Notification Center)"
    [dock]="Dock"
    [widgets]="Desktop widgets (Clock, Weather, Music, Reminders…)"
    [desktop]="Desktop icons (files, folders and apps in ~/Desktop)"
    [clock]="Clock app (World Clock, Alarms, Stopwatch, Timers)"
    [apps]="Finder, Photos, App Store, AirDrop and the video player"
    [lock]="Lock screen (MacLock)"
    [config]="Session config + helper scripts (wallpapers, Game Mode, lock)"
    [session]="\"Hyprland (MacShell)\" login session (separate, needs sudo)"
    [existing]="Start from my CURRENT Hyprland config instead of a separate session"
    [deps]="Dependencies (pacman + paru/yay)"
    [icons]="MacTahoe icon theme"
    [fonts]="Fonts (Inter, Roboto Flex, Nunito, Noto Serif Display)"
    [apply]="Apply the icons + font to GTK / Qt / KDE apps"
    [defaults]="Open pictures in Preview, folders in Finder, video in our player"
    [emoji]="Apple emoji font (fontconfig prefers it everywhere)"
    [wallpapers]="macOS 27 Golden Gate wallpapers"
    [sounds]="UI sounds + Clock alarm tones"
)
# the launch line every way of starting MacShell uses
#   QSG_USE_SIMPLE_ANIMATION_DRIVER: animations at each screen's own refresh rate (Qt otherwise paces them to the first screen)
#   MALLOC_ARENA_MAX: Qt runs ~50 threads; without it each gets its own heap arena (RAM that never comes back)
LAUNCH="while :; do pkill -x mako; QSG_USE_SIMPLE_ANIMATION_DRIVER=1 MALLOC_ARENA_MAX=2 qs -c MacShell; sleep 1; done"

c_b=$'\e[1m'; c_d=$'\e[2m'; c_g=$'\e[32m'; c_y=$'\e[33m'; c_r=$'\e[31m'; c_0=$'\e[0m'
say()  { printf '%s==>%s %s\n' "$c_g$c_b" "$c_0" "$*"; }
note() { printf '%s  ·%s %s\n' "$c_d" "$c_0" "$*"; }
warn() { printf '%s!!%s %s\n' "$c_y$c_b" "$c_0" "$*"; }
die()  { printf '%sxx%s %s\n' "$c_r$c_b" "$c_0" "$*" >&2; exit 1; }
ask()  { [ "$YES" = 1 ] && return 0; local a; read -r -p "$1 [Y/n] " a; [ -z "$a" ] || [[ "$a" =~ ^[Yy] ]]; }
have() { command -v "$1" >/dev/null 2>&1; }
known() { local f; for f in "${ORDER[@]}"; do [ "$f" = "$1" ] && return 0; done; return 1; }

PKGS=(quickshell rsync qt6-shadertools qt6-multimedia qt6-svg jq curl git ffmpeg imagemagick libnotify grim slurp wl-clipboard cliphist
      playerctl brightnessctl bluez-utils networkmanager power-profiles-daemon hypridle hyprlock hyprsunset wf-recorder
      mpvpaper awww inter-font noto-fonts-emoji python-numpy zenity openbsd-netcat libwebp
      yt-dlp poppler)

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

do_defaults() {
    say "Making MacShell's apps the defaults"
    have xdg-mime || { warn "xdg-mime missing: skipping"; return 0; }
    local m
    for m in image/png image/jpeg image/webp image/gif image/bmp image/tiff image/avif; do xdg-mime default macshell-preview.desktop "$m"; done
    xdg-mime default macshell-finder.desktop inode/directory
    for m in video/mp4 video/x-matroska video/webm video/quicktime; do xdg-mime default macshell-player.desktop "$m"; done
    note "Pictures → Preview, folders → Finder, video → Player"
}

do_emoji() {
    say "Apple emoji"
    local dir="$HOME/.local/share/fonts/apple-emoji" f="$dir/AppleColorEmoji.ttf"
    if [ -s "$f" ]; then note "already installed"; else
        mkdir -p "$dir"
        local url
        url=$(curl -sL --max-time 20 https://api.github.com/repos/samuelngs/apple-emoji-linux/releases/latest \
              | grep -o 'https://[^"]*AppleColorEmoji-Linux.ttf' | head -1)
        [ -n "$url" ] || { warn "could not find the font release; skipping"; return 0; }
        curl -L --max-time 600 -o "$f" "$url" || { warn "download failed"; return 0; }
    fi
    mkdir -p "$HOME/.config/fontconfig/conf.d"
    cp "$REPO/session/75-apple-emoji.conf" "$HOME/.config/fontconfig/conf.d/" 2>/dev/null
    fc-cache -f "$dir" >/dev/null 2>&1
    note "Apple Color Emoji installed for this user"
}

compile_shaders() {
    local qsb=/usr/lib/qt6/bin/qsb
    [ -x "$qsb" ] || qsb=$(command -v qsb || true)
    [ -n "$qsb" ] || { warn "qsb (qt6-shadertools) not found: the Liquid Glass shaders compile on first launch instead"; return 0; }
    for f in "$1"/*.frag; do [ -f "$f" ] && "$qsb" --qt6 -o "$f.qsb" "$f" >/dev/null 2>&1 || true; done
}

do_shell() {
    [ "$(installed_kind)" = original ] && backup_original
    say "Installing the shell"
    mkdir -p "$QS/MacShell" "$SHARE"
    # repo root = the shell (QML, shaders, assets); the running shell reloads by itself
    rsync -a --delete --exclude '.git' --exclude 'MacLock' --exclude 'session' --exclude 'install.sh' --exclude 'README*' \
          --exclude 'docs' --exclude '*.qsb' "$REPO"/ "$QS/MacShell"/
    compile_shaders "$QS/MacShell"
    cp "$REPO/install.sh" "$SHARE/install.sh"; chmod +x "$SHARE/install.sh"
    # MacShell's own apps (Clock) in the app launcher / Spotlight / Dock
    mkdir -p "$HOME/.local/share/applications"
    cp "$REPO"/session/applications/*.desktop "$HOME/.local/share/applications/" 2>/dev/null || true
    note "$QS/MacShell"
}

# ── feature switches: one shell, each part on or off (written into the settings files) ──
MACBAR="$HOME/.config/macbar/settings.json"
MACDOCK="$HOME/.config/macdock/settings.json"
WIDGETS="$HOME/.config/macshell/widgets.json"
set_json() {   # set_json <file> <key> <true|false>
    local f="$1" k="$2" v="$3" t
    have jq || { warn "jq is missing: can't set $k"; return 0; }
    mkdir -p "$(dirname "$f")"
    [ -s "$f" ] || printf '{}\n' > "$f"
    t=$(mktemp) && jq --arg k "$k" --argjson v "$v" '.[$k] = $v' "$f" > "$t" && mv "$t" "$f"
}
part_file() { case "$1" in dock|desktop) printf '%s' "$MACDOCK" ;; widgets) printf '%s' "$WIDGETS" ;; *) printf '%s' "$MACBAR" ;; esac; }
part_key()  {
    case "$1" in
        menubar) printf 'barEnabled' ;; spotlight) printf 'spotlightEnabled' ;; controlcenter) printf 'ccEnabled' ;;
        notifications) printf 'notificationsEnabled' ;; clock) printf 'clockAppEnabled' ;; desktop) printf 'desktopIcons' ;;
        dock) printf 'dockEnabled' ;; widgets) printf 'enabled' ;;
    esac
}
set_part() { set_json "$(part_file "$1")" "$(part_key "$1")" "$2"; }
do_menubar()       { say "Menu bar: on";       set_part menubar true; }
do_spotlight()     { say "Spotlight: on";      set_part spotlight true; }
do_controlcenter() { say "Control Center: on"; set_part controlcenter true; }
do_notifications() { say "Notifications: on";  set_part notifications true; }
do_dock()          { say "Dock: on";           set_part dock true; }
do_widgets()       { say "Desktop widgets: on"; set_part widgets true; }
do_clock()         { say "Clock app: on";      set_part clock true; }

# Apple Music: Cider, an Apple Music client for Linux by the Cider Collective (cider.sh).
# MacShell only ships a launcher that renames it; all credit stays with its authors.
do_applemusic() {
    say "Installing Apple Music (Cider)"
    have flatpak || { warn "flatpak is missing: ./install.sh --deps first"; return 0; }
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1
    flatpak install --user -y --noninteractive flathub sh.cider.Cider || warn "couldn't install Cider"
}

do_lock() {
    say "Installing the lock screen"
    mkdir -p "$QS/MacLock"
    rsync -a --delete --exclude '*.qsb' "$REPO/MacLock"/ "$QS/MacLock"/
    compile_shaders "$QS/MacLock"
    note "$QS/MacLock (used from the next lock on)"
}

do_config() {
    say "Installing the session config + scripts"
    mkdir -p "$SESS"
    # your custom/ overrides are never overwritten
    rsync -a --exclude 'custom/' "$REPO/session"/ "$SESS"/
    [ -d "$SESS/custom" ] || cp -r "$REPO/session/custom" "$SESS/custom"
    find "$SESS" -type f \( -name '*.conf' -o -name '*.lua' -o -name '*.sh' \) -exec sed -i "s|@HOME@|$HOME|g" {} +
    chmod +x "$SESS"/scripts/*.sh "$SESS"/hyprland/scripts/*.sh 2>/dev/null || true
    note "$SESS"
}

do_session() {
    [ -f "$SESS/install-sddm-session.sh" ] || do_config
    say "Adding the \"Hyprland (MacShell)\" login session"
    sudo sh "$SESS/install-sddm-session.sh"
    note "Pick \"Hyprland (MacShell)\" on your login screen. Your normal Hyprland session is untouched."
}

do_existing() {
    [ -d "$SESS/scripts" ] || do_config
    say "Starting MacShell from your current Hyprland config"
    local hc="$HOME/.config/hypr"
    if [ -f "$hc/hyprland.lua" ]; then
        local f="$hc/macshell.lua"
        cat > "$f" <<EOF
-- MacShell (added by install.sh)
hl.on("hyprland.start", function ()
    hl.exec_cmd("$SESS/scripts/macshell-wallpaper.sh")
    hl.exec_cmd("sh -c '$LAUNCH'")
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
exec-once = sh -c '$LAUNCH'
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
    say "Installing fonts (Inter, Roboto Flex, Nunito, Noto Serif Display)"
    have pacman && { pacman -Q inter-font >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm inter-font; }
    local F="$HOME/.local/share/fonts" G="https://github.com/google/fonts/raw/main/ofl"
    mkdir -p "$F/RobotoFlex" "$F/Nunito" "$F/NotoSerifDisplay"
    curl -fsSL -o "$F/RobotoFlex/RobotoFlex.ttf" "$G/robotoflex/RobotoFlex%5BGRAD,XOPQ,XTRA,YOPQ,YTAS,YTDE,YTFI,YTLC,YTUC,opsz,slnt,wdth,wght%5D.ttf"
    curl -fsSL -o "$F/RobotoFlex/OFL.txt" "$G/robotoflex/OFL.txt"
    # lock screen clock styles: Nunito (Classic / Thin), Noto Serif Display (Serif)
    curl -fsSL -o "$F/Nunito/Nunito.ttf" "$G/nunito/Nunito%5Bwght%5D.ttf"
    curl -fsSL -o "$F/Nunito/OFL.txt" "$G/nunito/OFL.txt"
    curl -fsSL -o "$F/NotoSerifDisplay/NotoSerifDisplay.ttf" "$G/notoserifdisplay/NotoSerifDisplay%5Bwdth,wght%5D.ttf"
    curl -fsSL -o "$F/NotoSerifDisplay/OFL.txt" "$G/notoserifdisplay/OFL.txt"
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
    [ -f "$SESS/scripts/macshell-make-sounds.py" ] || do_config
    say "Generating UI sounds"
    python3 "$SESS/scripts/macshell-make-sounds.py" || warn "needs python-numpy"
}

# ── uninstall: everything, or just some features ──
un_shell()    { pkill -f 'qs -c MacShell' 2>/dev/null || true; rm -rf "$QS/MacShell" "$SHARE"; rm -f "$HOME/.local/share/applications/macshell-clock.desktop"; note "removed the shell"; }
un_lock()     { rm -rf "$QS/MacLock"; note "removed the lock screen"; }
un_config()   { rm -rf "$SESS/hyprland" "$SESS/scripts"; note "removed the session config (kept $SESS/custom)"; }
un_session()  { ask "Remove the login session (sudo)?" && sudo rm -f /usr/share/wayland-sessions/hyprland-macshell.desktop /usr/local/bin/start-hyprland-macshell; }
un_existing() {
    rm -f "$HOME/.config/hypr/macshell.conf" "$HOME/.config/hypr/macshell.lua"
    sed -i '/macshell.conf/d' "$HOME/.config/hypr/hyprland.conf" 2>/dev/null || true
    sed -i '/require("macshell")/d' "$HOME/.config/hypr/hyprland.lua" 2>/dev/null || true
    note "removed MacShell from your Hyprland config"
}
un_sounds()   { rm -rf "$HOME/.local/share/sounds/macshell"; note "removed the sounds"; }
do_uninstall() {
    local what=("$@") f
    [ ${#what[@]} -eq 0 ] && what=(shell lock existing session)
    say "Removing: ${what[*]}"
    for f in "${what[@]}"; do
        if declare -F "un_$f" >/dev/null; then "un_$f"; else note "nothing to remove for '$f' (packages, icons, fonts and wallpapers are left alone)"; fi
    done
    note "your settings stay in ~/.config/macbar, ~/.config/macdock and ~/.config/macshell — delete them for a clean slate"
}

do_check() {
    say "Checking"
    local miss=() c
    for c in qs qsb hyprctl jq curl ffmpeg magick grim slurp wl-copy cliphist playerctl brightnessctl nmcli hypridle mpvpaper awww pw-play python3 rsync; do
        if have "$c" || { [ "$c" = qsb ] && [ -x /usr/lib/qt6/bin/qsb ]; }; then note "ok       $c"; else miss+=("$c"); printf '%s  ✗%s missing  %s\n' "$c_r" "$c_0" "$c"; fi
    done
    [ -d "$QS/MacShell" ] && note "shell:        installed" || warn "shell:        not installed (./install.sh --shell)"
    [ -d "$QS/MacLock" ]  && note "lock screen:  installed" || warn "lock screen:  not installed (./install.sh --lock)"
    [ -d "$SESS/scripts" ] && note "config:       installed" || note "config:       not installed (./install.sh --config)"
    [ -f /usr/share/wayland-sessions/hyprland-macshell.desktop ] && note "login session: Hyprland (MacShell)" || note "login session: not added (./install.sh --session)"
    [ ${#miss[@]} -eq 0 ] && say "Everything's there." || warn "${#miss[@]} missing — ./install.sh --deps installs them"
}

pull() {
    have git && [ -d "$REPO/.git" ] || { warn "$REPO is not a git checkout — using the files as they are"; return 0; }
    say "Getting the latest version"
    git -C "$REPO" pull --ff-only || die "couldn't update (local changes in $REPO?)"
}

run() {
    local s want p picked=0
    # picking any part of the shell pulls in the shell files it needs
    for p in "${PARTS[@]}"; do for want in "$@"; do [ "$want" = "$p" ] && picked=1; done; done
    if [ "$picked" = 1 ]; then
        local has=0; for want in "$@"; do [ "$want" = shell ] && has=1; done
        [ "$has" = 0 ] && set -- shell "$@"
    fi
    for s in "${ORDER[@]}"; do
        for want in "$@"; do [ "$want" = "$s" ] && "do_$s"; done
    done
    # parts you did not tick are switched off, so "only Spotlight and widgets" means only those run
    if [ "$picked" = 1 ]; then
        for p in "${PARTS[@]}"; do
            local on=0; for want in "$@"; do [ "$want" = "$p" ] && on=1; done
            [ "$on" = 0 ] && { note "${DESC[$p]%% —*}: off"; set_part "$p" false; }
        done
        pgrep -f 'qs -c MacShell' >/dev/null && note "MacShell is running: restart it (or log out and in) for the switches to take effect"
    fi
    say "Done. Log into \"Hyprland (MacShell)\" (or restart Hyprland). Settings: Apple menu → System Settings…"
}

# ── interactive checklist: type numbers to tick / untick, a = all, n = none, Enter = go ──
pick() {
    local title="$1"; shift
    local -a items=("$@") on=()
    local i
    for i in "${!items[@]}"; do on[$i]=1; done
    # a separate login session and "use my current config" exclude each other: start with the session
    for i in "${!items[@]}"; do [ "${items[$i]}" = existing ] && on[$i]=0; done
    while :; do
        printf '\n%s%s%s\n' "$c_b" "$title" "$c_0" >&2
        for i in "${!items[@]}"; do
            printf '  %s %2d) %s\n' "$([ "${on[$i]}" = 1 ] && printf '%s[x]%s' "$c_g" "$c_0" || printf '[ ]')" $((i + 1)) "${DESC[${items[$i]}]}" >&2
        done
        local a; read -r -p "Toggle numbers (e.g. 2 5), a = all, n = none, Enter = continue: " a
        [ -z "$a" ] && break
        case "$a" in
            a) for i in "${!items[@]}"; do on[$i]=1; done; continue ;;
            n) for i in "${!items[@]}"; do on[$i]=0; done; continue ;;
        esac
        for i in $a; do [[ "$i" =~ ^[0-9]+$ ]] && [ "$i" -ge 1 ] && [ "$i" -le ${#items[@]} ] && on[$((i - 1))]=$((1 - on[$((i - 1))])); done
    done
    for i in "${!items[@]}"; do [ "${on[$i]}" = 1 ] && printf '%s\n' "${items[$i]}"; done
}

# ── what's already there: nothing, the original MacShell (0-ss), or this edition ──
installed_kind() {
    local d="$QS/MacShell"
    [ -d "$d" ] || { echo none; return; }
    if [ -f "$d/ClockApp.qml" ] || [ -d "$QS/MacLock" ]; then echo tahoe; return; fi
    echo original
}
# the original lives in the same folder (a git clone): keep a copy before this edition takes the folder over
backup_original() {
    local b="$QS/MacShell.original-$(date +%Y%m%d-%H%M%S)"
    mv "$QS/MacShell" "$b"
    note "your original MacShell is saved in $b (your settings in ~/.config/macbar and ~/.config/macdock carry over)"
}

menu() {
    printf '\n%s  MacShell — Tahoe edition%s\n%s  macOS 26/27-style shell for Hyprland%s\n\n' "$c_b" "$c_0" "$c_d" "$c_0"
    case "$(installed_kind)" in
        original)
            printf '%sFound the original MacShell%s in %s.\n' "$c_b" "$c_0" "$QS/MacShell"
            printf '  1) Upgrade it to the Tahoe edition — only the shell + the new lock screen (keeps your settings)\n'
            printf '  2) Install the whole thing (shell, lock screen, session, fonts, icons, sounds…)\n'
            printf '  3) Let me pick\n'
            local u; read -r -p "Choose [1]: " u
            case "${u:-1}" in
                1) backup_original; run shell lock config sounds fonts; return ;;
                2) backup_original; run deps shell menubar spotlight controlcenter notifications dock widgets clock lock config session icons fonts apply wallpapers sounds; return ;;
            esac ;;
        tahoe)
            printf '%sMacShell (Tahoe edition) is already installed.%s\n' "$c_b" "$c_0"
            printf '  1) Update it (latest version, keeps your settings)\n  2) Install the whole thing again\n  3) Let me pick\n'
            local u; read -r -p "Choose [1]: " u
            case "${u:-1}" in
                1) pull; run shell lock config sounds; return ;;
                2) pull; run deps shell menubar spotlight controlcenter notifications dock widgets clock lock config icons fonts apply sounds; return ;;
            esac ;;
    esac
    printf '  1) Install\n  2) Update (gets the latest version first)\n  3) Check what is installed\n  4) Uninstall\n'
    local w; read -r -p "Choose [1]: " w
    local -a sel
    case "${w:-1}" in
        1) mapfile -t sel < <(pick "What do you want to install?" deps shell menubar spotlight controlcenter notifications dock widgets clock lock config session existing icons fonts apply wallpapers sounds) ;;
        2) pull; mapfile -t sel < <(pick "What do you want to update?" shell lock config sounds fonts icons) ;;
        3) do_check; return ;;
        4) mapfile -t sel < <(pick "What do you want to remove?" shell lock config session existing sounds); do_uninstall "${sel[@]}"; return ;;
        *) die "pick 1-4" ;;
    esac
    [ ${#sel[@]} -eq 0 ] && { note "nothing selected"; return; }
    run "${sel[@]}"
}

[ $# -eq 0 ] && { menu; exit 0; }
todo=(); mode=install; args=("$@"); i=0
while [ $i -lt ${#args[@]} ]; do
    a="${args[$i]}"
    case "$a" in
        -y|--yes) YES=1 ;;
        --all) todo+=(deps shell menubar spotlight controlcenter notifications dock widgets clock lock config session icons fonts apply wallpapers sounds) ;;
        --deps-only) do_deps; exit 0 ;;
        --only) i=$((i + 1)); IFS=',' read -r -a parts <<< "${args[$i]:-}"; for p in "${parts[@]}"; do known "$p" || die "unknown feature: $p"; todo+=("$p"); done ;;
        --update) mode=update ;;
        --uninstall) mode=uninstall ;;
        --check) do_check; exit 0 ;;
        -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
        --*) f="${a#--}"; known "$f" || die "unknown option: $a (see --help)"; todo+=("$f") ;;
        *) known "$a" || die "unknown feature: $a (see --help)"; todo+=("$a") ;;
    esac
    i=$((i + 1))
done
case "$mode" in
    update) pull; [ ${#todo[@]} -eq 0 ] && todo=(shell lock config); run "${todo[@]}" ;;
    uninstall) do_uninstall "${todo[@]}" ;;
    *) [ ${#todo[@]} -eq 0 ] && die "nothing to do (see --help)"; run "${todo[@]}" ;;
esac
