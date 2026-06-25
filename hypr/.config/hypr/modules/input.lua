-- ── Input ─────────────────────────────────────────────────────────────
-- GNOME-flavored touchpad defaults: natural scroll, tap-to-click,
-- clickfinger (2-finger = right click, 3-finger = middle click).

hl.config({
    input = {
        kb_layout    = "us",
        kb_variant   = "",
        kb_options   = "",

        follow_mouse = 1,
        sensitivity  = 0,           -- -1.0 .. 1.0, 0 = no change

        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
        },
    },
})

-- 3-finger horizontal swipe → switch workspaces
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
