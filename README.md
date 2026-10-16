# MacShell — Tahoe edition

A macOS 26/27-style desktop for **Hyprland**, built on **Quickshell**: Liquid Glass menu bar, Dock, Control Center,
Spotlight, desktop widgets, notifications and a full lock screen. This is a fork of
[0-ss/Macshell](https://github.com/0-ss/Macshell) with a lot added on top (see below). The original README follows.

## Install

```sh
git clone -b tahoe https://github.com/vsoultann/MacShell.git
cd MacShell
./install.sh            # interactive
./install.sh --all -y   # everything, no questions
```

| Option | What it does |
|---|---|
| `--deps` | Installs dependencies (Arch-based: pacman, plus paru/yay for AUR packages) |
| `--shell` | Installs / updates the shell (`~/.config/quickshell/MacShell`, `MacLock`, `~/.config/hypr-macshell`) |
| `--session` | Adds **"Hyprland (MacShell)"** to your login screen as a separate session — your own Hyprland config is untouched (sudo) |
| `--existing` | Starts MacShell from your *current* Hyprland config instead (Lua or hyprlang) |
| `--icons` | Installs the [MacTahoe](https://github.com/vinceliuice/MacTahoe-icon-theme) icon theme |
| `--fonts` | Installs Inter + Roboto Flex |
| `--apply` | Sets the icons + font for GTK, Qt and KDE apps |
| `--wallpapers` | Downloads the macOS 27 Golden Gate light & dark wallpapers |
| `--sounds` | Generates the UI sound effects |
| `--uninstall` | Removes the shell (keeps your settings) |

Settings live in the shell itself: Apple menu → **System Settings…** (Install dependencies and Reset MacShell are in About / General).

## What's new in this edition

- **Lock screen (MacLock)** — glass clock that stretches like iOS 26's, Now Playing with album-tinted bubble, shuffle / repeat,
  in-bubble or side-by-side synced lyrics, enlarge-the-cover artwork mode with blurred album background, Caps Lock
  indicator, drag the bubble between spots, PAM unlock, animated wallpapers.
- **System Settings** rebuilt like macOS: Wi-Fi (with Ethernet), Bluetooth, Network, Battery & Energy Mode, Control Center,
  Desktop & Dock, Displays & Night Shift, Notifications, Sound (devices + input), Focus, Lock Screen, Users & Groups,
  Keyboard, Mouse, Trackpad, Wallpaper (with light/dark/dynamic Golden Gate), Reset, Install dependencies.
- **Desktop widgets** — Clock, World Clock, Calendar, Weather (macOS large layout), Batteries, Music, Notes, Photos,
  Reminders, Stocks; Liquid Glass / Frosted / Tinted / Opaque, drag, resize with motion-morph, glass that follows a live wallpaper.
- **Animated wallpapers** that are cheap: an optimized 30 fps copy decoded on the iGPU, one player per monitor, paused
  automatically while windows cover the desktop or the screen is locked.
- **Notifications** — Liquid Glass banners that morph into the Notification Center, disintegrate on Clear All, sounds only for
  system notifications.
- Spotlight hover glow + smooth fade, blur + morph text transitions everywhere, auto contrast (dark text on bright backgrounds),
  Game Mode, UI sounds, drag Dock icons / window previews / clipboard items onto the desktop to open them,
  state that survives a crash (Do Not Disturb, Night Shift, …), ~4 % idle CPU.

## Credits

- [0-ss/Macshell](https://github.com/0-ss/Macshell) — the original MacShell (menu bar, Dock, Liquid Glass shader). All credit for the base goes there.
- The session config started from [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (GPL-3.0).
- [MacTahoe icon theme](https://github.com/vinceliuice/MacTahoe-icon-theme) by vinceliuice (GPL-3.0) — `assets/music-app.svg` comes from it.
- [Roboto Flex](https://github.com/googlefonts/roboto-flex) (OFL) and [Inter](https://rsms.me/inter/) (OFL), downloaded by the installer.
- Lyrics: [LRCLIB](https://lrclib.net) and NetEase Cloud Music. Weather: [Open-Meteo](https://open-meteo.com).
- Apple's wallpapers belong to Apple and are not included — `--wallpapers` downloads them.

---

# MacShell

A macOS Tahoe–style **menu bar + Dock** for Hyprland, built on [Quickshell](https://quickshell.org), with a real-time
"Liquid Glass" refraction shader, window previews, Spotlight, clipboard/emoji picker, notifications, Control Center,
screenshots,record video, a wallpaper picker and an Alt+Tab switcher — all in one Quickshell process.

> **Heads up:** this targets **Hyprland 0.55+ with a Lua config** (`hyprland.lua`) and a recent **Quickshell (0.3.x)**.
> See [Requirements](#requirements) and [Known issues](#known-issues).

## Files

| File | Purpose |
|---|---|
| `shell.qml` | Entry point. Shared hub: window geometry, wallpaper lookup, capture gating. |
| `MacBar.qml` | Menu bar, Control Center, Spotlight, notifications, switcher, screenshots, wallpaper picker. |
| `MacDock.qml` | Dock, window previews, and the Settings window. |
| `liquidglass.frag` | Liquid Glass fragment shader (compiled to `.qsb` on first run). |
| `EmojiData.js` | Emoji fallback data for Spotlight (from [gemoji](https://github.com/github/gemoji), MIT). |

Keep all five files in the same folder.

## Requirements

### Required

| What | Why |
|---|---|
| **Hyprland ≥ 0.55, running a Lua config** (`~/.config/hypr/hyprland.lua`) | Window actions, the Alt+Tab focus, "paste after picking" and Log Out use Lua dispatches (`hyprctl dispatch 'hl.dsp…'`, `hyprctl eval`). On older versions or a `.conf` session these actions fail; the bar, Dock, glass and previews still work. Quick test: `hyprctl dispatch 'hl.dsp.no_op()'` must not error. |
| **Quickshell ≥ 0.3.0** (0.3.2 recommended) | Needs the Hyprland module (`HyprlandToplevel`, `lastIpcObject`, Lua-config support), `ScreencopyView`, `IpcHandler`, and the UPower / Pipewire / Mpris / SystemTray / Notifications services. |
| Quickshell built with **Wayland**, **Hyprland**, **Screencopy → Hyprland Toplevel Export**, **Pipewire**, **UPower**, **Mpris**, **System Tray** | Distro packages normally enable all of these. Check the build info that `qs` prints in its logs. |
| **Qt 6.5+** with `qt6-declarative`, `qt6-wayland`, **`qt6-shadertools`** (provides `qsb`) | `QtQuick.Effects` (MultiEffect) needs 6.5+. `qsb` compiles `liquidglass.frag` on first run. Without it (and without a prebuilt `liquidglass.frag.qsb`) the glass falls back to "Normal Blur". |
| `qt6-svg` (recommended) | SVG app icons. |
| `hyprctl`, `sh`, `xdg-open` | Core. |
| An **icon theme** (Papirus, Adwaita, …) set for Qt apps | App icons in the Dock and Spotlight come from the system theme. If icons are blank, set one with `qt6ct` or `QS_ICON_THEME`. |
| Font **Inter** (default) | Falls back to the system font; "Noto Sans" / "System" can be chosen in Settings. |

### Optional (missing tools just disable that feature)

| Feature | Tool(s) |
|---|---|
| Screenshots (Print key) | `grim`, `wl-clipboard` (clipboard copy), `libnotify` (`notify-send`) |
| Clipboard history + Emoji (Spotlight) | `wl-clipboard`, `cliphist` (the shell starts the `wl-paste --watch cliphist store` watchers itself) |
| Screen recording | `wf-recorder` |
| Color picker | `hyprpicker` |
| Night Shift | `hyprsunset` |
| Brightness | `brightnessctl` |
| Wi-Fi / VPN / Ethernet | NetworkManager (`nmcli`); fallback editor `nm-connection-editor` or `nmtui` |
| Bluetooth | `bluez` (`bluetoothctl`) |
| Audio device routing | `wpctl` (WirePlumber) or `pactl` |
| Privacy indicators | PipeWire (`pw-dump`) |
| Keep Awake | `systemd-inhibit` |
| Lock / Sleep / Restart / Shut Down | `loginctl`, `systemctl` (UWSM sessions are stopped via `uwsm`) |
| Trash watching / emptying | `inotify-tools` (`inotifywait`), `ktrash6`/`ktrash5`, or a file manager (`dolphin`, `nautilus`, `thunar`, `nemo`, `pcmanfm-qt`) |
| Folder pickers in Settings | `zenity`, `kdialog` or `yad` |
| "About This Linux" | `fastfetch` or `neofetch` |
| Do Not Disturb (Focus) | `dunstctl`, `makoctl` or `swaync-client` (only if you keep one of those) |
| Emoji search keywords | `emoji-test.txt` from the `unicode-emoji` package (otherwise `EmojiData.js` is used) |
| Wallpaper detection / applying | one of: Noctalia, `awww`/`swww`, `hyprpaper`, `swaybg`, `wpaperd` — or set a path yourself (see [Wallpaper](#wallpaper)) |
| Default apps | terminal `kitty`, file opener `xdg-open` — change `terminal`, `launcher`, `filesCmd`, `clipboardCmd` in `~/.config/macbar/settings.json` |

### Conflicts

This shell **replaces** your bar, dock and notification daemon. Stop anything that overlaps:

- Other bars/shells (waybar, hyprpanel, ags, Noctalia, Caelestia, …) and docks (nwg-dock, …).
- Notification daemons (`dunst`, `mako`, `swaync`): the bar owns `org.freedesktop.Notifications`.
  `systemctl --user disable --now dunst` (or `mako` / `swaync`).

## Install

1. Install the requirements above. On Arch, for example:
   ```sh
   sudo pacman -S hyprland quickshell qt6-declarative qt6-wayland qt6-shadertools qt6-svg \
        grim wl-clipboard wf-recorder cliphist libnotify brightnessctl networkmanager bluez-utils inotify-tools \
        ttf-inter noto-fonts-emoji
   ```
   Other distros: install the equivalents. Fedora has a Quickshell COPR; Nix has `pkgs.quickshell`.
2. Put the project in a Quickshell config folder. The folder name is the config name:
   ```sh
   git clone https://github.com/0-ss/MacShell ~/.config/quickshell/MacShell
   ```
   Don't reach it through a symlink; Quickshell ≥ 0.3 derives its state folders from the link path.
3. Try it:
   ```sh
   qs -c MacShell (or use qs -c ~/.config/quickshell/MacShell)
   ```
   On first run with the Liquid Glass style, `liquidglass.frag` is compiled with `qsb` and cached in
   `~/.config/macdock/liquidglass.frag.qsb`. Watch for `[macbar-glass] state: ready` in the log.
4. Add the Hyprland config below, then autostart it.

## Hyprland configuration (Lua)

```lua
-- autostart (remove other bars / docks / notification daemons first)
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c macshell")
end)

-- layer rules: blur for the glass surfaces
hl.layer_rule({ name = "macdock",  match = { namespace = "macdock"  }, blur = true, ignore_alpha = 0.2,  no_anim = true })
hl.layer_rule({ name = "macspot",  match = { namespace = "macspot"  }, blur = true, ignore_alpha = 0.05, no_anim = true })
hl.layer_rule({ name = "macbarbg", match = { namespace = "macbarbg" }, blur = true, ignore_alpha = 0.05, no_anim = true })
hl.layer_rule({ name = "macshot",  match = { namespace = "macshot"  }, no_anim = true })   -- optional: no fade on the screenshot picker

-- Settings window (fixed size). Hyprland usually floats it on its own; if it tiles, add a float rule for the title
-- "macshell Settings" (see /usr/share/hypr/hyprland.lua for the window_rule syntax of your version).

-- keybinds (the name after -c must match your folder name)

hl.bind("SUPER + V",         hl.dsp.exec_cmd(qs .. "spotlight clipboard"))
hl.bind("SUPER + period",     hl.dsp.exec_cmd("qs -c ~/.config/quickshell/MacShell ipc call spotlight emoji"))
hl.bind("SUPER + Space",     hl.dsp.exec_cmd("qs -c ~/.config/quickshell/MacShell ipc call spotlight toggle"))
hl.bind("ALT + TAB",     hl.dsp.exec_cmd("qs -c ~/.config/quickshell/MacShell ipc call switcher next"))
hl.bind("CTRL + ALT + W",     hl.dsp.exec_cmd("qs -c ~/.config/quickshell/MacShell ipc call wallpapers toggle"))
hl.bind("PRINT",     hl.dsp.exec_cmd("qs -c ~/.config/quickshell/MacShell ipc call screenshot region"))
```

Also make sure **blur is enabled** in your Hyprland `decoration` settings, or the "Normal Blur" style won't blur.

### IPC reference

`qs -c macshell ipc call <target> <function>`

| Target | Functions |
|---|---|
| `spotlight` | `toggle`, `clipboard`, `emoji`, `apps` |
| `screenshot` | `region`, `screen`, `window` |
| `wallpapers` | `toggle`, `open`, `close` |
| `switcher` | `next`, `prev`, `commit`, `cancel` |
| `settings` | `open` (works even if both the bar and the Dock are disabled) |
| `glass` | `captures true\|false` (window previews on/off, same as Settings → Dock Behavior → *Live window capture*) |

## Wallpaper

The Liquid Glass refracts your wallpaper, so the shell needs its file path. It looks, in order, at: the `wallpaperPath`
override in `settings.json`, Noctalia's `settings.toml`, `awww`/`swww query`, `hyprctl hyprpaper listactive`, and
`~/.config/hypr/hyprpaper.conf`. If yours isn't detected (swaybg, wpaperd, a custom script), either pick a wallpaper in the
built-in picker (Ctrl+Alt+W; it remembers the path), or set `"wallpaperPath": "/path/to/image.png"` in
`~/.config/macdock/settings.json`. The picker reads `~/Pictures/Wallpapers` by default (`wallpaperDir`).

## Where things are stored

| Path | Content |
|---|---|
| `~/.config/macbar/settings.json` | Menu bar settings |
| `~/.config/macdock/settings.json`, `pinned.json` | Dock settings and pinned apps |
| `~/.config/macdock/liquidglass.frag.qsb` | Compiled shader cache |
| `~/.cache/macbar/` | Clipboard history helper files (images, timestamps) |
| `~/Pictures/Screenshots` | Default screenshot folder |

Clipboard history is kept on disk (cliphist's database plus `~/.cache/macbar/clip`). Turn it off with `clipHistory: false`
in `~/.config/macbar/settings.json` if you don't want that.

## Troubleshooting

| Symptom | Check |
|---|---|
| Glass looks flat / "Normal Blur" | `qsb` missing (install `qt6-shadertools`) — the log shows `[macbar-glass] state: failed`. Or ship a prebuilt `liquidglass.frag.qsb` next to `liquidglass.frag`; it is used as a fallback. |
| Glass shows no wallpaper | Wallpaper not detected: see [Wallpaper](#wallpaper). |
| Blank app icons | No Qt icon theme: set one (`qt6ct`, or `QS_ICON_THEME`) and install it. |
| No notifications | Another daemon owns the D-Bus name. Disable it and restart the shell. |
| Window menu actions, Alt+Tab focus, paste-after-pick or Log Out do nothing | Not on a Lua-config Hyprland 0.55+: run `hyprctl dispatch 'hl.dsp.no_op()'`. |
| No window previews / glass behind windows | Quickshell built without Hyprland Toplevel Export, or Settings → Dock Behavior → *Live window capture* is off. |
| Log | `qs log` (see `qs --help` for selecting the config). |

## Known issues

**Shell crash with `wl_display#1: error 0: invalid object NNN`** when many windows open/close quickly (a game launching,
spamming terminals) while live window capture runs. A window closes while a capture frame for it is still pending; Hyprland
does not answer that frame, the shell then destroys it, and the compositor drops the Wayland connection. Mitigations:

- Settings → Menu Bar → turn **Real-time glass** off (far fewer captures; the biggest win).
- Settings → Dock Behavior → turn **Live window capture** off.
- The shell already pauses glass captures while windows open/close.
- Auto-restart it: `sh -c 'while :; do qs -c macshell; sleep 1; done'` as the autostart command.

Glitchy window capture,
Can be disabled in Settings:

- Settings → Dock Behavior → turn **Live window capture** off.

Reproduced on Hyprland 0.56.2 / Quickshell 0.3.2

## Credits

Emoji data from [GitHub gemoji](https://github.com/github/gemoji) (MIT).
