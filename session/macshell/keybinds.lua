-- MacShell session keys. Settings → Keyboard Shortcuts writes ~/.config/macshell/keybinds.lua, which is read
-- after this file and re-binds MacShell's own shortcuts (Spotlight, Finder, Control Center, …) to your keys.
local mac = "qs -c MacShell ipc call "
local function ipc(cmd) return hl.dsp.exec_cmd(mac .. cmd) end
local function first(...)       -- the first of these programs that is installed
    local s = ""
    for _, c in ipairs({ ... }) do s = s .. "command -v " .. c:match("^%S+") .. " >/dev/null && exec " .. c .. "; " end
    return hl.dsp.exec_cmd("sh -c '" .. s .. "'")
end

-- ── MacShell (defaults; Settings → Keyboard Shortcuts can change these) ──
hl.bind("SUPER + Space", ipc("spotlight toggle"), { description = "MacShell: Spotlight" })
hl.bind("SUPER + SUPER_L", ipc("spotlight toggle"), { release = true })
hl.bind("SUPER + V", ipc("spotlight clipboard"), { description = "MacShell: Clipboard history" })
hl.bind("SUPER + Period", ipc("spotlight emoji"), { description = "MacShell: Emoji picker" })
hl.bind("SUPER + A", ipc("spotlight apps"), { description = "MacShell: All applications" })
hl.bind("SUPER + C", ipc("controlcenter toggle"), { description = "MacShell: Control Center" })
hl.bind("SUPER + N", ipc("notifications open"), { description = "MacShell: Notification Center" })
hl.bind("SUPER + T", ipc("clock open"), { description = "MacShell: Clock" })
hl.bind("SUPER + SHIFT + A", ipc("appstore open"), { description = "MacShell: App Store" })
hl.bind("SUPER + Comma", ipc("settings open"), { description = "MacShell: System Settings" })
hl.bind("SUPER + SHIFT + S", ipc("screenshot region"), { description = "MacShell: Screenshot a region" })
hl.bind("CTRL + ALT + W", ipc("wallpapers toggle"), { description = "MacShell: Wallpapers" })
hl.bind("SUPER + G", ipc("gaming toggle"), { description = "MacShell: Game Mode" })
hl.bind("SUPER + SHIFT + D", ipc("airdrop open"), { description = "MacShell: AirDrop" })
hl.bind("SUPER + E", ipc("finder open"), { description = "MacShell: Finder" })
hl.bind("SUPER + M", ipc("window minimize"), { description = "MacShell: Minimize window" })
hl.bind("SUPER + SHIFT + M", ipc("window restorelast"), { description = "MacShell: Bring back the last minimized window" })
hl.bind("SUPER + W", hl.dsp.window.close(), { description = "MacShell: Close window" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen_state({ internal = 2, client = 0 }), { description = "MacShell: Zoom (fullscreen)" })
-- fixed
hl.bind("ALT + Tab", ipc("switcher next"), { description = "MacShell: Window switcher" })
hl.bind("ALT + SHIFT + Tab", ipc("switcher prev"))
hl.bind("ALT_L", ipc("switcher commit"), { ignore_mods = true, transparent = true, release = true })
hl.bind("SUPER + I", ipc("settings open"))
hl.bind("CTRL + SUPER + T", ipc("wallpapers toggle"))
hl.bind("CTRL + SUPER + R", hl.dsp.exec_cmd("pkill -x qs"), { description = "MacShell: Restart the shell" })
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("pidof wlogout || wlogout -p layer-shell"), { description = "Session: Log out / power" })

-- ── Laptop keys (work on the lock screen too; MacShell shows the volume / brightness HUD) ──
local sink, source = "@DEFAULT_AUDIO_SINK@", "@DEFAULT_AUDIO_SOURCE@"
-- like a Mac: a volume key also unmutes
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-mute " .. sink .. " 0; wpctl set-volume -l 1 " .. sink .. " 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-mute " .. sink .. " 0; wpctl set-volume " .. sink .. " 5%-"), { locked = true, repeating = true })
hl.bind("SHIFT + ALT + XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 " .. sink .. " 1%+"), { locked = true, repeating = true })
hl.bind("SHIFT + ALT + XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume " .. sink .. " 1%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute " .. sink .. " toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute " .. source .. " toggle"), { locked = true })
hl.bind("ALT + XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute " .. source .. " toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -q s 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q -n1 s 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: Play / pause" })
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Media: Next track" })
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Media: Previous track" })
hl.bind("SUPER + ALT + M", hl.dsp.exec_cmd("wpctl set-mute " .. source .. " toggle"), { locked = true, description = "Media: Mute microphone" })

-- ── Screenshots ──
local shotDir = "\"$(xdg-user-dir PICTURES)/Screenshots\""
local grimOut = "grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\""
hl.bind("Print", hl.dsp.exec_cmd(grimOut .. " - | wl-copy"), { locked = true, description = "Screenshot: Screen to clipboard" })
hl.bind("CTRL + Print", hl.dsp.exec_cmd("mkdir -p " .. shotDir .. " && " .. grimOut .. " " .. shotDir .. "/Screenshot_\"$(date '+%Y-%m-%d_%H.%M.%S')\".png && wl-copy < \"$(ls -t " .. shotDir .. "/*.png | head -n1)\""),
        { locked = true, description = "Screenshot: Screen to file and clipboard" })
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Utilities: Pick a colour" })

-- ── Windows ──
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("SUPER + SHIFT + ALT + Q", hl.dsp.exec_cmd("hyprctl kill"), { description = "Window: Force quit (click one)" })
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: Move" })
hl.bind("SUPER + mouse:274", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Window: Resize" })
for key, dir in pairs({ Left = "l", Right = "r", Up = "u", Down = "d" }) do
    hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = dir }), { description = "Window: Focus " .. key })
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }), { description = "Window: Move " .. key })
end
hl.bind("SUPER + Semicolon", hl.dsp.layout("splitratio -0.1"), { repeating = true })
hl.bind("SUPER + Apostrophe", hl.dsp.layout("splitratio +0.1"), { repeating = true })
hl.bind("SUPER + ALT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Float / tile" })
hl.bind("SUPER + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Window: Maximize" })
hl.bind("SUPER + ALT + F", hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }), { description = "Window: Fullscreen spoof" })
hl.bind("SUPER + P", hl.dsp.window.pin(), { description = "Window: Pin on top" })

-- ── Workspaces ──
local numcodes = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }      -- the number row on any keyboard layout
for i = 1, 10 do
    hl.bind("SUPER + code:" .. numcodes[i], hl.dsp.focus({ workspace = i }), { description = "Workspace: Go to " .. i })
    hl.bind("SUPER + ALT + code:" .. numcodes[i], hl.dsp.window.move({ workspace = i, follow = false }), { description = "Window: Send to workspace " .. i })
end
hl.bind("CTRL + SUPER + Left", hl.dsp.focus({ workspace = "r-1" }), { description = "Workspace: Previous" })
hl.bind("CTRL + SUPER + Right", hl.dsp.focus({ workspace = "r+1" }), { description = "Workspace: Next" })
hl.bind("SUPER + Page_Up", hl.dsp.focus({ workspace = "r-1" }))
hl.bind("SUPER + Page_Down", hl.dsp.focus({ workspace = "r+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "+1" }))
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "-1" }))
hl.bind("SUPER + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "r-1" }), { description = "Window: Send to workspace left" })
hl.bind("SUPER + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "r+1" }), { description = "Window: Send to workspace right" })
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("special"), { description = "Workspace: Scratchpad" })
hl.bind("SUPER + ALT + S", hl.dsp.window.move({ workspace = "special:special", follow = false }), { description = "Window: Send to scratchpad" })

-- ── Zoom ──
local function zoom(d)
    local z = hl.get_config("cursor:zoom_factor") + d
    hl.config({ cursor = { zoom_factor = math.max(1.0, math.min(3.0, z)) } })
end
hl.bind("SUPER + Minus", function() zoom(-0.3) end, { repeating = true, description = "Screen: Zoom out" })
hl.bind("SUPER + Equal", function() zoom(0.3) end, { repeating = true, description = "Screen: Zoom in" })

-- ── Session ──
hl.bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Session: Lock" })
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"), { locked = true, description = "Session: Sleep" })

-- ── Apps ──
local terminal = first("kitty -1", "foot", "alacritty", "wezterm", "konsole", "xterm")
hl.bind("SUPER + Return", terminal, { description = "App: Terminal" })
hl.bind("CTRL + ALT + T", terminal)
hl.bind("SUPER + B", first("google-chrome-stable", "zen-browser", "firefox", "brave", "chromium", "librewolf"), { description = "App: Browser" })
hl.bind("SUPER + X", first("kate", "gnome-text-editor", "code"), { description = "App: Text editor" })
hl.bind("CTRL + SUPER + V", first("pavucontrol-qt", "pavucontrol"), { description = "App: Volume mixer" })
hl.bind("CTRL + SHIFT + Escape", first("gnome-system-monitor", "plasma-systemmonitor", "kitty -1 btop"), { description = "App: Task manager" })

-- ── Virtual machines: SUPER + ALT + F1 passes every key to the VM until pressed again ──
hl.define_submap("virtual-machine", function()
    hl.bind("SUPER + ALT + F1", function()
        if hl.get_current_submap() == "virtual-machine" then hl.dispatch(hl.dsp.submap("reset"))
        else hl.dispatch(hl.dsp.submap("virtual-machine")) end
    end, { submap_universal = true })
end)
