-- ── Monitors ─────────────────────────────────────────────────────────
-- Framework 16 internal panel = eDP-1 (BOE NE160QDM-NZ6, 2560x1600 @ 165Hz).
-- VRR (FreeSync) enabled; calibrated ICC profile applied (per Arch wiki).
--   vrr: 1 = always on. If you see brightness flicker on static content,
--        change to 2 (fullscreen only).
--   icc profile: ~/.local/share/icc/BOE_NE160QDM_NZ6.icm (notebookcheck calibration).
-- See: https://wiki.hypr.land/Configuring/Basics/Monitors/
--
-- Docked with a monitor on the eGPU (EGPU_PRESENT=1 and EGPU_DISPLAYS=1, both
-- exported by ~/.config/uwsm/env at login), eDP-1 is DISABLED for the whole
-- session: every panel frame would otherwise be rendered on the NVIDIA card and
-- blitted over OCuLink to the AMD iGPU, and a dpms cycle on that path wedges the
-- panel (the aquamarine#324 topology -- see egpu-dpms-guard). Disabled from its
-- first commit, the AMD secondary renderer is never initialised and dpms never
-- touches the panel. Undocked -- or docked with nothing plugged into the eGPU --
-- the rule is enabled and nothing changes.
--
-- Do NOT re-enable eDP-1 live in a docked session: that is exactly the re-light
-- path aquamarine 0.14.0 breaks. To keep the panel while docked, set
-- EGPU_DISPLAYS=0 in ~/.config/uwsm/env and re-login.
--
-- Positions are unchanged: DP-11 at 1600x0 and DP-9 at 3520x0 are explicit, so
-- the empty 0..1600 strip left while the panel is off is harmless.

local home = os.getenv("HOME")
local panel_off = os.getenv("EGPU_PRESENT") == "1" and os.getenv("EGPU_DISPLAYS") == "1"

hl.monitor({
    output   = "eDP-1",
    disabled = panel_off,       -- docked with a display on the eGPU -> off
    mode     = "2560x1600@165",
    position = "0x0",           -- far left; anchors the external layout
    scale    = "auto",
    vrr      = 1,
    cm       = "srgb",
    icc      = home .. "/.local/share/icc/BOE_NE160QDM_NZ6.icm",
})

-- ── External displays (eGPU: RTX 3080 Ti via OCuLink) ─────────────────
-- Driven by the NVIDIA card (0000:c1:00.0). Left-to-right layout:
--   eDP-1 (0..1600) | DP-11 (1600..3520) | DP-9 (3520..5440), logical px.
-- Positions are explicit so the order is exact regardless of probe order.
-- Safe when mobile: Hyprland ignores rules for connectors that are absent,
-- and egpu-drm-devices drops NVIDIA from AQ_DRM_DEVICES when undocked.
-- x-offset 1600 assumes eDP-1 scale 1.6 -> 1600 logical wide (2560 / 1.6).

-- Middle: Acer XZ270 Z, high-refresh gaming panel (240 Hz rated; 280 OC avail).
-- VRR stays OFF: this VA panel gamma-pulses whenever adaptive sync is active at
-- the wire -- vrr=1 pulsed on the static desktop, vrr=2 pulsed in every
-- fullscreen app (verified against the kernel VRR_ENABLED prop, 2026-08).
-- NOTE: a vrr change + `hyprctl reload` does NOT reach the connector; it needs
-- a modeset (e.g. bounce mode 240->120->240) before the wire state changes.
hl.monitor({
    output   = "DP-11",
    mode     = "1920x1080@240",
    position = "1600x0",
    scale    = 1,
    vrr      = 0,
})

-- Far right: Acer KA242Y, 60 Hz.
hl.monitor({
    output   = "DP-9",
    mode     = "1920x1080@60",
    position = "3520x0",
    scale    = 1,
    vrr      = 1,               -- FreeSync: idle desktop drops to low refresh so the eGPU stays cool (fans off)
})

-- ── Workspace layout ─────────────────────────────────────────────────
-- Pin workspaces to monitors so the mapping is stable (Hyprland's default
-- auto-assignment otherwise drifts). default:true makes each the monitor's
-- startup workspace, so DP-11 (high-refresh) is the primary / workspace 1.
-- Mobile-safe: if a bound monitor is absent (undocked), Hyprland falls the
-- workspace back onto the internal panel. Workspaces 4-10 open on whichever
-- monitor is focused (default Hyprland behaviour).
--   WS1 -> DP-11 (high-refresh gaming panel — primary)
--   WS2 -> DP-9  (second external)
--   WS3 -> eDP-1 (laptop panel), bound only while the panel is on; with eDP-1
--          disabled (docked) WS3 opens on the focused monitor, like 4-10
hl.workspace_rule({ workspace = "1", monitor = "DP-11", default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-9",  default = true })
if not panel_off then
    hl.workspace_rule({ workspace = "3", monitor = "eDP-1", default = true })
end
