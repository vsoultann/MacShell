-- any display not named in monitors.lua
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 5,
        gaps_workspaces = 50,
        border_size = 1,
        col = { active_border = "rgba(52434277)", inactive_border = "rgba(23191933)" },
        resize_on_border = true,
        no_focus_fallback = true,
        allow_tearing = true,          -- lets the `immediate` rule (games) work
        snap = { enabled = true, window_gap = 4, monitor_gap = 5, respect_gaps = true },
    },
    decoration = {
        rounding = 18,
        rounding_power = 2.5,
        -- MacShell draws its own glass; compositor blur is switched on per surface in rules.lua
        blur = {
            enabled = true, xray = true, special = false, new_optimizations = true,
            size = 6, passes = 2, brightness = 1, noise = 0, contrast = 0.89,
            vibrancy = 0.5, vibrancy_darkness = 0.5,
            popups = false, popups_ignorealpha = 0.6,
            input_methods = true, input_methods_ignorealpha = 0.8,
        },
        shadow = { enabled = true, range = 20, offset = { 0, 2 }, render_power = 3, color = "rgba(00000020)" },
        dim_inactive = true,
        dim_strength = 0.05,
        dim_special = 0.2,
    },
    dwindle = { preserve_split = true, smart_split = false, smart_resizing = false },
    misc = {
        background_color = "rgba(1a1111FF)",
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 0,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
        enable_swallow = false,
        on_focus_under_fullscreen = 2,
        allow_session_lock_restore = true,
        session_lock_xray = true,
        initial_workspace_tracking = false,
        focus_on_activate = true,
    },
    binds = { scroll_event_delay = 0, hide_special_on_workspace_change = true },
    cursor = { zoom_factor = 1, zoom_rigid = false, zoom_disable_aa = true, hotspot_padding = 1 },
    xwayland = { force_zero_scaling = true },
    animations = { enabled = true },
})

-- Animations
local curves = {
    emphasizedDecel = { { 0.05, 0.7 }, { 0.1, 1 } },
    emphasizedAccel = { { 0.3, 0 }, { 0.8, 0.15 } },
    standardDecel   = { { 0, 0 }, { 0, 1 } },
    menu_decel      = { { 0.1, 1 }, { 0, 1 } },
    menu_accel      = { { 0.52, 0.03 }, { 0.72, 0.08 } },
    stall           = { { 1, -0.1 }, { 0.7, 0.85 } },
}
for name, pts in pairs(curves) do hl.curve(name, { type = "bezier", points = pts }) end
for _, a in ipairs({
    { "windowsIn",           3,   "emphasizedDecel", "popin 80%" },
    { "fadeIn",              3,   "emphasizedDecel" },
    { "windowsOut",          2,   "emphasizedDecel", "popin 90%" },
    { "fadeOut",             2,   "emphasizedDecel" },
    { "windowsMove",         3,   "emphasizedDecel", "slide" },
    { "border",              10,  "emphasizedDecel" },
    { "layersIn",            2.7, "emphasizedDecel", "popin 93%" },
    { "layersOut",           2.4, "menu_accel",      "popin 94%" },
    { "fadeLayersIn",        0.5, "menu_decel" },
    { "fadeLayersOut",       2.7, "stall" },
    { "workspaces",          7,   "menu_decel",      "slide" },
    { "specialWorkspaceIn",  2.8, "emphasizedDecel", "slidevert" },
    { "specialWorkspaceOut", 1.2, "emphasizedAccel", "slidevert" },
    { "zoomFactor",          3,   "standardDecel" },
}) do
    hl.animation({ leaf = a[1], enabled = true, speed = a[2], bezier = a[3], style = a[4] })
end
