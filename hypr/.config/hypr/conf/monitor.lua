-------------------------------------------------------
-- Monitor Setup
-- name: "Default"
-------------------------------------------------------

hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = 1,
})

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
