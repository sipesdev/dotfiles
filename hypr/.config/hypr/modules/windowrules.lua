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

-- Float + center the Bitwarden extension unlock popup (Brave).
hl.window_rule({
    name  = "float-bitwarden-popup",
    match = { class = "^(brave-nngceckbapebfimnlniiiahkandclblb-Default)$" },
    float = true,
    center = true,
})

-- Float + center the agent terminal (spawned by ~/.local/bin/agent and the
-- crash toast). Expression sizes resolve once, at map time -- fine for a
-- transient session window. Fallback if expressions misparse: size = { 1500, 950 }.
hl.window_rule({
    name   = "float-agent-tui",
    match  = { class = "^agent-tui$" },
    float  = true,
    center = true,
    size   = { "(monitor_w*0.6)", "(monitor_h*0.6)" },
})

-- No animation for the Quickshell bar/popouts — prevents the resize "bounce"
-- when the status center grows (e.g. expanding the Wi-Fi list).
hl.layer_rule({
    name    = "quickshell-noanim",
    match   = { namespace = "quickshell" },
    no_anim = true,
})
