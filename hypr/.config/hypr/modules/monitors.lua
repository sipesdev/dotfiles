-- ── Monitors ─────────────────────────────────────────────────────────
-- Framework 16 internal panel = eDP-1 (BOE NE160QDM-NZ6, 2560x1600 @ 165Hz).
-- VRR (FreeSync) enabled; calibrated ICC profile applied (per Arch wiki).
--   vrr: 1 = always on. If you see brightness flicker on static content,
--        change to 2 (fullscreen only).
--   icc profile: ~/.local/share/icc/BOE_NE160QDM_NZ6.icm (notebookcheck calibration).
-- See: https://wiki.hypr.land/Configuring/Basics/Monitors/

hl.monitor({
    output   = "eDP-1",
    mode     = "2560x1600@165",
    position = "auto",
    scale    = "auto",
    vrr      = 1,
    cm       = "srgb",
    icc      = "/home/michael/.local/share/icc/BOE_NE160QDM_NZ6.icm",
})
