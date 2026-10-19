-- MacShell session: a standalone Hyprland config. Nothing here comes from another shell's dotfiles.
--   macshell/*.lua   the session (env, look, input, rules, keys, autostart)
--   custom/*.lua     your own additions; read after the session files, so they win
--   ~/.config/macshell/{windows,keybinds}.lua   written by MacShell's Settings, read last
HOME = os.getenv("HOME")
local function exists(p) local f = io.open(p, "r"); if f then f:close(); return true end; return false end
local function custom(name)
    if exists(HOME .. "/.config/hypr-macshell/custom/" .. name .. ".lua") then require("custom." .. name) end
end

require("macshell.env");      custom("env")
require("macshell.look");     custom("general")
require("macshell.input")
require("macshell.rules");    custom("rules")
require("macshell.keybinds"); custom("keybinds")
require("macshell.execs");    custom("execs")

-- displays are shared with the main session (stretchres owns these files).
-- dofile, not require: a rewritten stretchres.lua must be read again on reload
for _, f in ipairs({ "workspaces.lua", "monitors.lua", "stretchres.lua" }) do
    if exists(HOME .. "/.config/hypr/" .. f) then dofile(HOME .. "/.config/hypr/" .. f) end
end

-- Settings → Desktop & Dock → "Open windows floating", and Settings → Keyboard Shortcuts
pcall(dofile, HOME .. "/.config/macshell/windows.lua")
pcall(dofile, HOME .. "/.config/macshell/keybinds.lua")
