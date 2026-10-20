-- Displays coming and going, the macOS way. Unplugging a display moves its workspaces (and their windows) onto
-- whatever display is left; Hyprland then leaves them there when it is plugged back in. MacShell remembers which
-- display each workspace lived on and, when that display returns, sends the workspaces home and focuses it.
-- The record survives reloads and restarts (~/.cache/macshell/workspace-homes).
local file = (os.getenv("HOME") or "") .. "/.cache/macshell/workspace-homes"
local home = {}

pcall(function()
    local f = io.open(file, "r")
    if not f then return end
    for line in f:lines() do
        local id, mon = line:match("^(%-?%d+)%s+(%S+)$")
        if id then home[tonumber(id)] = mon end
    end
    f:close()
end)

local function connected(name)
    for _, m in ipairs(hl.get_monitors()) do if m.name == name then return true end end
    return false
end

local function save()
    pcall(function()
        local f = io.open(file, "w")
        if not f then return end
        for id, mon in pairs(home) do f:write(id, " ", mon, "\n") end
        f:close()
    end)
end

-- where every workspace is now, except the ones whose display is unplugged: those keep their old home
local function remember()
    local changed = false
    for _, ws in ipairs(hl.get_workspaces()) do
        if not ws.special and ws.id > 0 and ws.monitor then
            local h = home[ws.id]
            if not (h and not connected(h)) and h ~= ws.monitor.name then
                home[ws.id] = ws.monitor.name
                changed = true
            end
        end
    end
    if changed then save() end
end

local function bringHome(name)
    local moved = false
    for _, ws in ipairs(hl.get_workspaces()) do
        if not ws.special and home[ws.id] == name and ws.monitor and ws.monitor.name ~= name then
            hl.dispatch(hl.dsp.workspace.move({ workspace = ws.id, monitor = name }))
            moved = true
        end
    end
    return moved
end

pcall(remember)
for _, ev in ipairs({ "workspace.created", "workspace.active", "workspace.move_to_monitor", "monitor.focused" }) do
    hl.on(ev, function() pcall(remember) end)
end
-- the display needs a moment to be set up (mode, position) before workspaces can move onto it
hl.on("monitor.added", function(m)
    local name = type(m) == "table" and m.name or tostring(m)
    hl.timer(function()
        pcall(function()
            if bringHome(name) then hl.dispatch(hl.dsp.focus({ monitor = name })) end
            remember()
        end)
    end, { timeout = 1200, type = "oneshot" })
end)
