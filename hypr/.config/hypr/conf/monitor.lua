-------------------------------------------------------
-- Monitor Setup
-- name: "Default"
-------------------------------------------------------

-- Keep this layout explicit.  `auto` assigns outputs in connector-discovery
-- order, which is not stable across a dock or Hyprland restart.  The laptop
-- panel remains at the origin; the two dock displays are physically arranged
-- DP-12 (left) then DP-16 (right).
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-12", mode = "preferred", position = "2256x0", scale = 1 })
hl.monitor({ output = "DP-16", mode = "preferred", position = "4816x0", scale = 1 })

-- Fallback for an unfamiliar output when away from the dock.
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

hl.on("monitor.layout_changed", function() hl.exec_cmd("hypr-lid-manager reconcile") end)
