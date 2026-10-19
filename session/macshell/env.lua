local home = os.getenv("HOME")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XDG_MENU_PREFIX", "plasma-")
-- Apple's pointer for apps that draw their own (most use the compositor's, set by macshell-cursor.sh)
hl.env("XCURSOR_THEME", "macOS")
hl.env("XCURSOR_SIZE", "24")
local data = os.getenv("XDG_DATA_DIRS") or ""
hl.env("XDG_DATA_DIRS", home .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share:" .. data)
-- "MacShell" first: xdg-open then reads ~/.config/macshell-mimeapps.list before mimeapps.list, so folders open
-- in our Finder in this session only; the portals still find hyprland-portals.conf
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
