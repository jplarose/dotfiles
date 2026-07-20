-- Configuration
local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Applications
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("kitty"), { description = "Open the terminal" })
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("firefox"), { description = "Open the browser" })
hl.bind(
	mainMod .. " + SHIFT + B",
	hl.dsp.exec_cmd("google-chrome-stable"),
	{ description = "Open the secondary browser" }
)
hl.bind(mainMod .. " + CTRL + C", hl.dsp.exec_cmd("kitty --class calculator qalc"), { description = "Open calculator" })
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("slack"), { description = "Open Slack" })

-- Focus and move workspaces directly through Hyprland.  Keep these bindings
-- independent of monitor layout so they remain available with any display
-- configuration.
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(
		mainMod .. " + " .. key,
		hl.dsp.focus({ workspace = i }),
		{ description = "Focus workspace " .. i }
	)

	hl.bind(
		mainMod .. " + SHIFT + " .. key,
		hl.dsp.window.move({ workspace = i }),
		{ description = "Move window to workspace " .. i }
	)
end
-- Windows
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Close active window" })
hl.bind(
	mainMod .. " + SHIFT + Q",
	hl.dsp.exec_cmd("hyprctl activewindow | grep pid | tr -d 'pid:' | xargs kill"),
	{ description = "Quit active window and all open instances" }
)
hl.bind(
	mainMod .. " + F",
	hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
	{ description = "Toggle Fullscreen" }
)
hl.bind(
	mainMod .. " + M",
	hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),
	{ description = "Toggle Maximize Window" }
)
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle Floating" })
hl.bind(mainMod .. " + ALT + T", function()
	hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
	hl.dispatch(hl.dsp.window.pin())
end, { description = "Toggle floating + pinned" })
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), { description = "Toggle split" })
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }), { description = "Move focus left" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Move focus right" })
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }), { description = "Move focus up" })
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }), { description = "Move focus down" })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window with the mouse" })
hl.bind(
	mainMod .. " + mouse:273",
	hl.dsp.window.resize(),
	{ mouse = true, description = "Resize window with the mouse" }
)
hl.bind(
	mainMod .. " + SHIFT + right",
	hl.dsp.window.resize({ x = 100, y = 0, relative = true }),
	{ repeating = true },
	{ description = "Increase window width with keyboard" }
)
hl.bind(
	mainMod .. " + SHIFT + left",
	hl.dsp.window.resize({ x = -100, y = 0, relative = true }),
	{ repeating = true },
	{ description = "Reduce window width with keyboard" }
)
hl.bind(
	mainMod .. " + SHIFT + down",
	hl.dsp.window.resize({ x = 0, y = 100, relative = true }),
	{ repeating = true },
	{ description = "Increase window height with keyboard" }
)
hl.bind(
	mainMod .. " + SHIFT + up",
	hl.dsp.window.resize({ x = 0, y = -100, relative = true }),
	{ repeating = true },
	{ description = "Reduce window height with keyboard" }
)
hl.bind(mainMod .. " + G", hl.dsp.group.toggle(), { description = "Toggle window group" })
hl.bind(mainMod .. " + K", hl.dsp.layout("swapsplit"), { description = "Swapsplit" })
hl.bind(mainMod .. " + ALT + left", hl.dsp.window.swap({ direction = "l" }), { description = "Swap tiled window left" })
hl.bind(
	mainMod .. " + ALT + right",
	hl.dsp.window.swap({ direction = "r" }),
	{ description = "Swap tiled window right" }
)
hl.bind(mainMod .. " + ALT + up", hl.dsp.window.swap({ direction = "u" }), { description = "Swap tiled window up" })
hl.bind(mainMod .. " + ALT + down", hl.dsp.window.swap({ direction = "d" }), { description = "Swap tiled window down" })

-- Actions
hl.bind(mainMod .. " + CTRL + R", hl.dsp.exec_cmd("hyprctl reload"), { description = "Reload Hyprland configuration" })
hl.bind(
	mainMod .. " + SHIFT + E",
	hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"),
	{ description = "Exit Hyprland session" }
)
hl.bind(
	mainMod .. " + PRINT",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh"),
	{ description = "Take a screenshot" }
)
hl.bind(
	mainMod .. " + ALT + F",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh --instant"),
	{ description = "Take an instant full-screen screenshot" }
)
hl.bind(
	mainMod .. " + SHIFT + S",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh --instant-area"),
	{ description = "Take an instant area screenshot" }
)
hl.bind(
	mainMod .. " + ALT + A",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/text-extractor.sh"),
	{ description = "Extract text from an area" }
)
hl.bind(
	mainMod .. " + CTRL + RETURN",
	hl.dsp.exec_cmd("rofi -show drun -replace -i"),
	{ description = "Open application launcher" }
)
hl.bind(
	mainMod .. " + CTRL + K",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/keybindings.sh"),
	{ description = "Show keybindings" }
)
hl.bind(
	mainMod .. " + V",
	hl.dsp.exec_cmd("cliphist list | rofi -dmenu -i -p Clipboard | cliphist decode | wl-copy"),
	{ description = "Open clipboard history" }
)
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"), { description = "Lock screen" })

-- Scroll through workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Switch to next workspace" })
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Switch to previous workspace" })

-- Multimedia and brightness keys
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true, description = "Raise volume" }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true, description = "Lower volume" }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true, description = "Mute audio" }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true, description = "Mute microphone" }
)
hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),
	{ locked = true, repeating = true, description = "Increase brightness" }
)
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),
	{ locked = true, repeating = true, description = "Decrease brightness" }
)

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Next track" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Pause audio" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play audio" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Previous track" })
