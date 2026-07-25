hl.on("hyprland.start", function()
	-- Export variables to systemd
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

	-- Restart portals so they catch the environment
	hl.exec_cmd("systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal")

	-- Start wallpaper daemon
	hl.exec_cmd("hyprpaper")

	-- Build one Waybar config per currently visible output.  This keeps the
	-- grouped workspace buttons portable across docks and connector names.
	hl.exec_cmd("hypr-waybar-manager start")

	-- Start polkit daemon
	hl.exec_cmd("systemctl --user start hyprpolkitagent")

	-- Start swaync
	hl.exec_cmd("swaync")

	-- Start hypridle unless this machine explicitly opts out.
	if os.getenv("HYPRIDLE_ENABLED") ~= "0" then
		hl.exec_cmd("hypridle")
	end

	-- Start OpenVPN Connection
	hl.exec_cmd("nm-applet indicator")

	-- Run the VPN service prompting for user credentials
	hl.exec_cmd("systemctl --user start spectervpn.service")

	-- Reconcile laptop lid and docking policy.
	hl.exec_cmd("hypr-lid-manager start")

	-- Load cliphist history
	hl.exec_cmd("wl-paste --watch cliphist store")
end)
