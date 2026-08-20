-- ── Environment variables ────────────────────────────────────────────
-- AMD hardware (Radeon 890M): NO NVIDIA vars, and NO SDL_VIDEODRIVER
-- (it breaks modern Proton — Omarchy dropped it).
-- These cover apps launched within the Hyprland session. Session-global
-- copies also live in ~/.config/uwsm/env (written in the login phase).

-- Cursor
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Adwaita")

-- Toolkits → Wayland
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
-- Qt theming (Kvantum matte-black for Qt5 & Qt6) -- login-phase copy lives in ~/.config/uwsm/env
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Electron / Chromium (Brave web apps, VS Code, etc.) → native Wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Gaming: shared DXVK tuning for every Proton/Wine game -- login-phase copy
-- lives in ~/.config/uwsm/env (see the dxvk package)
hl.env("DXVK_CONFIG_FILE", os.getenv("HOME") .. "/.config/dxvk/dxvk.conf")

-- Desktop identity (also set by uwsm via the .desktop DesktopNames)
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
