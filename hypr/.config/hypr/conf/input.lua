-- -----------------------------------------------------
-- Input
-- -----------------------------------------------------

hl.config({
	cursor = {
		inactive_timeout = 0,
		hide_on_key_press = false,
		hide_on_touch = false,
		hide_on_tablet = false,
		invisible = false,
	},

	input = {
		kb_layout = "us",

		-- Let hovered windows handle the pointer; keep keyboard focus on click.
		follow_mouse = 2,

		sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
			disable_while_typing = true,
		},
	},
})
