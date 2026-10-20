local home = os.getenv("HOME")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XDG_MENU_PREFIX", "plasma-")
-- Apple's pointer for apps that draw their own (most use the compositor's, set by macshell-cursor.sh)
hl.env("XCURSOR_THEME", "macOS")
hl.env("XCURSOR_SIZE", "24")
-- MacShell's own KDE / Qt look (Finder = Dolphin, QuickTime Player = VLC), this session only: qt/xdg holds the
-- locked kdeglobals + dolphinrc that macshell-kde-theme.sh writes, qt/share the Finder toolbar, the Finder and
-- QuickTime Player launchers and the MacTahoe colour schemes. Both go first, so they win here and nowhere else.
local qtdir = home .. "/.config/hypr-macshell/qt"
-- each list: ours first, then what was there, every folder once (this file runs again on every reload, and an
-- unconditional prepend used to grow XDG_DATA_DIRS by a full copy each time)
local function dirs(first, existing)
    local out, seen = {}, {}
    local function add(d) if d ~= "" and not seen[d] then seen[d] = true; out[#out + 1] = d end end
    for _, d in ipairs(first) do add(d) end
    for d in (existing or ""):gmatch("[^:]+") do add(d) end
    return table.concat(out, ":")
end
hl.env("XDG_CONFIG_DIRS", dirs({ qtdir .. "/xdg" }, (os.getenv("XDG_CONFIG_DIRS") or "") .. ":/etc/xdg"))
hl.env("XDG_DATA_DIRS", dirs({ qtdir .. "/share", home .. "/.local/share/flatpak/exports/share",
                               "/var/lib/flatpak/exports/share", "/usr/local/share", "/usr/share" }, os.getenv("XDG_DATA_DIRS")))
-- "MacShell" first: xdg-open then reads ~/.config/macshell-mimeapps.list before mimeapps.list, so folders open in
-- Finder (Dolphin) and videos in QuickTime Player (VLC) in this session only; the portals still find hyprland-portals.conf
hl.env("XDG_CURRENT_DESKTOP", "MacShell:Hyprland")

-- MacShell runs on upstream Quickshell (~/.local/opt/quickshell-upstream) when it is installed
local qs = home .. "/.local/opt/quickshell-upstream"
local f = io.open(qs .. "/usr/bin/qs", "r")
if f then
    f:close()
    local path = os.getenv("PATH") or ""
    if not path:find(qs .. "/usr/bin", 1, true) then hl.env("PATH", qs .. "/usr/bin:" .. path) end
    hl.env("QML2_IMPORT_PATH", qs .. "/usr/lib/qt6/qml")
    hl.env("QML_IMPORT_PATH", qs .. "/usr/lib/qt6/qml")
end
