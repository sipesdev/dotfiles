-- ── Window rules ──────────────────────────────────────────────────────
-- See: https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Ignore maximize requests from all apps (tiling-friendly).
hl.window_rule({
    name           = "suppress-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix dragging issues with empty XWayland surfaces.
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, pin = false },
    no_focus = true,
})

-- Float common dialogs / system pickers (centered).
hl.window_rule({
    name  = "float-dialogs",
    match = { title = "^(Open File|Save File|Save As|Open Folder|Choose Files|Authentication Required)$" },
    float = true,
})

hl.window_rule({
    name  = "float-tools",
    match = { class = "^(org.pulseaudio.pavucontrol|pavucontrol|blueman-manager|nm-connection-editor|org.gnome.Calculator)$" },
    float = true,
})

-- Float + center zenity dialogs (Wi-Fi password prompt, errors).
hl.window_rule({
    name  = "float-zenity",
    match = { class = "^(zenity)$" },
    float = true,
})

-- No animation for the Quickshell bar/popouts — prevents the resize "bounce"
-- when the status center grows (e.g. expanding the Wi-Fi list).
hl.layer_rule({
    name    = "quickshell-noanim",
    match   = { namespace = "quickshell" },
    no_anim = true,
})
