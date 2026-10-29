# Waybar

Both themes live in this GNU Stow package. `themes/default` preserves the
original configuration and styling without changes. `themes/v2.3` is the
HANCORE V2.3 experiment. The tracked `.config/waybar/theme` file selects the
theme, and Hyprland starts it through `~/.local/bin/waybar-theme start`.

From the repository root, install or refresh the links with:

```bash
stow --restow --no-folding -t "$HOME" waybar hypr
```

Switch themes with:

```bash
~/.local/bin/waybar-theme default  # Restore the original bar
~/.local/bin/waybar-theme v2.3     # Try the new bar again
```

Switching updates the selection in this repo, re-stows Waybar, and restarts
Waybar if it is already running. If stopped, run `~/.local/bin/waybar-theme start`
in your graphical session. Changes are left uncommitted for review.

V2.3 source: https://github.com/HANCORE-linux/waybar-themes/tree/a4cdf25484c37ad8588cabc019e06c8c40b203e9/config/V2.3

The adaptation uses the existing Matugen colors and replaces Omarchy actions
with Rofi, Kitty, top, NetworkManager, Blueman, Pavucontrol, and wpctl. Omarchy
indicators and the unconfigured weather module are removed. Backlight detection
is automatic. Pacman updates appear only if `waybar-module-pacman-updates` is
installed; no additional packages are installed by this change. The upstream
MIT license is included with the theme.
