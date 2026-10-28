-------------------------------------------------------
-- Monitor Setup
-- name: "Default"
-------------------------------------------------------

-- Start the panel at the origin; the lid manager reapplies its saved left/right
-- position after profiles resolve dock routes to current connector names.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1 })

local hostname_file = io.open("/etc/hostname", "r")
local hostname = hostname_file and hostname_file:read("*l") or ""
if hostname_file then hostname_file:close() end

local profiles = {
	framework13 = "framework13",
	specterops = "specterops",
}
local profile = profiles[hostname]
local dock_command = profile and require("conf.monitors." .. profile) or nil

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

local pending = false
local function reconcile()
	if pending then return end
	pending = true
	hl.timer(function()
		pending = false
		-- Resolve the dock first, then park/unpark the panel, then reconcile
		-- workspaces inside the lid manager. A failed dock query must still
		-- allow the lid policy to restore a usable laptop display.
		local command = "hypr-lid-manager start"
		if dock_command then command = dock_command .. "; " .. command end
		hl.exec_cmd(command)
	end, { timeout = 500, type = "oneshot" })
end

hl.on("monitor.added", reconcile)
hl.on("monitor.removed", reconcile)
hl.on("monitor.layout_changed", reconcile)
hl.on("hyprland.start", reconcile)
reconcile() -- Restart missing helpers and reconcile on config reload too.

return { reconcile = reconcile }
