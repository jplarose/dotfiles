-------------------------------------------------------
-- Monitor Setup
-- name: "Default"
-------------------------------------------------------

-- Keep the laptop panel at the origin.  Dock connector names are local to a
-- machine, so the external layout is selected from a hostname-specific
-- profile below rather than being shared globally.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1 })

local hostname_file = io.open("/etc/hostname", "r")
local hostname = hostname_file and hostname_file:read("*l") or ""
if hostname_file then hostname_file:close() end

local profiles = {
	framework13 = "framework13",
	specterops = "specterops",
}
local profile = profiles[hostname]
if profile then require("conf.monitors." .. profile) end

-- Fallback for an unfamiliar output or host without a profile.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.bind(
	"switch:on:Lid Switch",
	hl.dsp.exec_cmd("hypr-lid-manager close"),
	{ locked = true, description = "Handle laptop lid closing" }
)

hl.bind(
	"switch:off:Lid Switch",
	hl.dsp.exec_cmd("hypr-lid-manager open"),
	{ locked = true, description = "Handle laptop lid opening" }
)

hl.on("monitor.layout_changed", function()
	-- Reconcile workspace slots independently of lid handling.  A desktop
	-- machine has no eDP-1, so hypr-lid-manager correctly exits early there;
	-- workspace ownership still needs to follow the monitors' x positions.
	hl.exec_cmd("hypr-workspace-manager reconcile")
	hl.exec_cmd("hypr-lid-manager reconcile")
end)
