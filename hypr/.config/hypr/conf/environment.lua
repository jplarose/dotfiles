-- User command paths
local home = os.getenv("HOME")
local path = os.getenv("PATH") or ""
hl.env("PATH", home .. "/.local/bin:" .. home .. "/.cargo/bin:" .. path)

-- Prefer native Wayland backends while retaining X11 fallback where needed.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("SDL_VIDEODRIVER", "wayland")

-- Session identity for portals and desktop applications.
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
