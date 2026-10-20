-- ── Windows ──
-- MacShell draws its own glass, so the compositor blurs no window (Settings turns it back on for itself below)
hl.window_rule({ match = { class = ".*" }, no_blur = true })
hl.window_rule({ match = { float = 0 }, no_shadow = true })
hl.window_rule({ match = { pin = 1 }, border_color = "rgba(ffb3b1AA) rgba(ffb3b177)" })

-- dialogs float in the middle
for _, t in ipairs({ "^(Open File)(.*)$", "^(Select a File)(.*)$", "^(Open Folder)(.*)$", "^(Save As)(.*)$",
                     "^(Library)(.*)$", "^(File Upload)(.*)$", "^(.*)(wants to save)$", "^(.*)(wants to open)$" }) do
    hl.window_rule({ match = { title = t }, float = true, center = true })
end
for _, c in ipairs({ "^(pavucontrol)$", "^(org.pulseaudio.pavucontrol)$", "^(nm-connection-editor)$" }) do
    hl.window_rule({ match = { class = c }, float = true, center = true, size = { "(monitor_w*0.45)", "(monitor_h*0.45)" } })
end
hl.window_rule({ match = { class = "org.freedesktop.impl.portal.desktop.kde" }, float = true, size = { "(monitor_w*0.60)", "(monitor_h*0.65)" } })
hl.window_rule({ match = { class = "^(blueberry\\.py)$" }, float = true })
hl.window_rule({ match = { class = "kcm_.*" }, float = true })
hl.window_rule({ match = { class = ".*bluedevilwizard" }, float = true })

-- picture-in-picture: small, pinned, bottom right
local pip = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$"
hl.window_rule({ match = { title = pip }, float = true, pin = true, keep_aspect_ratio = true,
                 move = { "(monitor_w*0.73)", "(monitor_h*0.72)" }, size = { "(monitor_w*0.25)", "(monitor_h*0.25)" } })
-- "… is sharing your screen" bars
hl.window_rule({ match = { title = ".*is sharing (a window|your screen).*" }, float = true, pin = true,
                 move = { "(monitor_w*.5-window_w*.5)", "(monitor_h-window_h-12)" } })

-- games skip vsync
for _, t in ipairs({ ".*\\.exe", ".*minecraft.*" }) do hl.window_rule({ match = { title = t }, immediate = true }) end
hl.window_rule({ match = { class = "^(steam_app).*" }, immediate = true })

-- MacShell's own windows
hl.window_rule({ match = { class = "^org\\.quickshell$", title = "^macshell Settings$" }, float = true, no_blur = false })
for title, size in pairs({ Clock = "780 540", ["App Store"] = "1080 720", Photos = "1100 740", Finder = "1020 660",
                           AirDrop = "620 500", Preview = "960 660", Player = "900 540", ["Install Dependencies"] = "720 480" }) do
    hl.window_rule({ match = { class = "^org\\.quickshell$", title = "^" .. title .. "$" }, float = true, size = size, center = true })
end

hl.workspace_rule({ workspace = "special:special", gaps_out = 30 })

-- ── Layers ──
hl.layer_rule({ match = { namespace = ".*" }, xray = true })
-- the menu bar strip and the Dock blur what is really behind them, live: windows too, not only the wallpaper
hl.layer_rule({ match = { namespace = "^(macbarbg|macdock)$" }, xray = false })
-- MacShell animates its own surfaces
hl.layer_rule({ match = { namespace = "^(macspot|macbar|macbarbg|macdock|macshot|macwidgets|macwelcome|macshell-minimize|macdock-drag|macauth)$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^macdock$" }, blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "^macbarbg$" }, blur = true, ignore_alpha = 0.05 })
-- Spotlight draws its own Liquid Glass (compositor blur behind it stayed solid while it faded)
hl.layer_rule({ match = { namespace = "^macspot$" }, blur = false })
-- the welcome screen sits above the bar and the Dock
hl.layer_rule({ match = { namespace = "^macwelcome$" }, order = 10 })
for _, ns in ipairs({ "selection", "hyprpicker", "noanim", "gtk4-layer-shell" }) do
    hl.layer_rule({ match = { namespace = ns }, no_anim = true })
end
hl.layer_rule({ match = { namespace = "gtk-layer-shell" }, blur = true, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "logout_dialog" }, blur = true })    -- wlogout
