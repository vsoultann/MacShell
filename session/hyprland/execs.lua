-- MacShell session: ii is NOT started here. MacShell owns bar, dock, notifications,
-- clipboard watchers (it starts wl-paste|cliphist itself) and the wallpaper (awww).
hl.on("hyprland.start", function ()
    hl.exec_cmd("$HOME/.config/hypr-macshell/hyprland/scripts/start_geoclue_agent.sh")
    hl.exec_cmd("$HOME/.config/hypr-macshell/scripts/macshell-wallpaper.sh")
    -- auto-restart loop: upstream known issue (wl_display invalid object crash)
    -- mako gets D-Bus-activated if a notification arrives while MacShell is down (crash/restart) and then keeps the
    -- notification slot: stop it before every (re)start so MacShell always owns notifications
    hl.exec_cmd("sh -c 'while :; do pkill -x mako; qs -c MacShell; sleep 1; done'")

    -- Core components (authentication, lock screen)
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("hypridle -c $HOME/.config/hypr-macshell/hypridle.conf")
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    -- Audio
    hl.exec_cmd("easyeffects --hide-window --service-mode")

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
end)
