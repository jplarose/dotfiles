-- MONITORS
require("conf.monitor")

-- INPUT
require("conf.input")

-- GESTURE
require("conf.gestures")

-- AUTOSTART
require("conf.autostart")

-- COLORS
require("colors")

-- CONFIGURATION
require("conf.environment")
require("conf.window")
require("conf.decoration")
require("conf.layout")
require("conf.workspace")
require("conf.misc")
require("conf.keybinding")
require("conf.windowrule")
require("conf.animation")
require("conf.ml4w")

-- CUSTOM
local f = io.open(os.getenv("HOME") .. "/.config/hypr/custom.lua", "r")
if f then
	f:close()
	require("custom")
end

-- HYPRMOD
require("hyprland-gui")
