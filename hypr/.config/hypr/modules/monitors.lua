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
    position = "0x0",           -- far left; anchors the external layout
    scale    = "auto",
    vrr      = 1,
    cm       = "srgb",
    icc      = "/home/michael/.local/share/icc/BOE_NE160QDM_NZ6.icm",
})

-- ── External displays (eGPU: RTX 3080 Ti via OCuLink) ─────────────────
-- Driven by the NVIDIA card (0000:c1:00.0). Left-to-right layout:
--   eDP-1 (0..1600) | DP-11 (1600..3520) | DP-9 (3520..5440), logical px.
-- Positions are explicit so the order is exact regardless of probe order.
-- Safe when mobile: Hyprland ignores rules for connectors that are absent,
-- and egpu-drm-devices drops NVIDIA from AQ_DRM_DEVICES when undocked.
-- x-offset 1600 assumes eDP-1 scale 1.6 -> 1600 logical wide (2560 / 1.6).

-- Middle: Acer XZ270 Z, high-refresh gaming panel (240 Hz rated; 280 OC avail).
hl.monitor({
    output   = "DP-11",
    mode     = "1920x1080@240",
    position = "1600x0",
    scale    = 1,
})

-- Far right: Acer KA242Y, 60 Hz.
hl.monitor({
    output   = "DP-9",
    mode     = "1920x1080@60",
    position = "3520x0",
    scale    = 1,
})
