hl.on("hyprland.start", function ()
    -- Export variables to systemd
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    -- Restart portals so they catch the environment
    hl.exec_cmd("systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal")

    -- Start wallpaper daemon
    hl.exec_cmd("hyprpaper")

    -- Start waybar
    hl.exec_cmd("waybar -c ~/.config/waybar/themes/default/config -s ~/.config/waybar/themes/default/style.css")

    -- Start polkit daemon
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- Start swaync
    hl.exec_cmd("swaync")

    -- Start hypridle
    hl.exec_cmd("hypridle")

    -- Load cliphist history
    hl.exec_cmd("wl-paste --watch cliphist store")

end)
