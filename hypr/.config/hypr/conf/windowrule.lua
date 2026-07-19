-- Picture-in-picture windows should remain visible without stealing focus.
hl.window_rule({
    name = "picture-in-picture",
    match = {
        title = [[^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$]],
    },
    float = true,
    pin = true,
    focus_on_activate = false,
    no_initial_focus = true,
    suppress_event = "activate",
})

-- Keep the screen-share picker accessible above other windows.
hl.window_rule({
    name = "hyprland-share-picker",
    match = { class = "hyprland-share-picker" },
    float = true,
    pin = true,
    center = true,
    size = "600 400",
})
