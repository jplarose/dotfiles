-------------------------------------------------------
-- Gestures
-------------------------------------------------------

-- Workspaces
hl.gesture({ fingers = 3, direction = "up", action = function() hl.exec_cmd("hypr-workspace-manager cycle next") end })
hl.gesture({ fingers = 3, direction = "down", action = function() hl.exec_cmd("hypr-workspace-manager cycle previous") end })

-- Scrolling
--hl.gesture({
--	fingers = 3,
--	direction = "horizontal",
--	action = "scroll_move",
--	scale = 0.9,
--})
