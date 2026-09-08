-- ── Quake agent console ───────────────────────────────────────────────
-- A dimmed overlay console (special workspace "console") that drops down over
-- the current workspace on SUPER+grave (bound in modules/bindings.lua) and is
-- seeded with the default coding agent the first time it opens. Ported from
-- Omarchy Quattro's qconsole.lua (MIT). The SUPER+S "magic" scratchpad is a
-- separate, untouched workspace.

local home = os.getenv("HOME")

-- How much of the usable screen the console covers, measured from the top.
local share = 0.5

-- Seed on first open rather than at boot, so nothing runs until wanted. The
-- exec rule must pin the workspace itself: Hyprland only tags a spawn with the
-- workspace it came from while misc.initial_workspace_tracking is on. Class
-- agent-console, NOT agent-tui: the float-agent-tui rule must not float this
-- window -- the console tiles to fill the workspace the gaps below shape.
local seed = "[workspace special:console silent] alacritty --class agent-console -e "
    .. home .. "/.local/bin/agent --inline"

-- Dimming only applies while a special workspace is open, so the console gets
-- its separation from the workspace underneath for free the rest of the time.
hl.config({
    decoration = {
        dim_special = 0.6,
    },
})

-- Refitting replaces the rule in place rather than stacking a new one, but it
-- still schedules a refresh, and monitor.focused fires on every hop between
-- screens. Only write the rule when the number actually moves.
local covering = nil

local function cover(bottom)
    if covering == bottom then
        return
    end
    covering = bottom

    hl.workspace_rule({
        workspace = "special:console",
        gaps_in = 0,
        gaps_out = { top = 0, right = 0, bottom = bottom, left = 0 },
        -- No border: the console is set apart by the dimming behind it.
        no_border = true,
        on_created_empty = seed,
    })
end

-- Sizing with a window rule would freeze the console at whatever the screen
-- measured when it first opened (Hyprland resolves those expressions once, as
-- the window maps). Gaps are re-applied by the layout instead, so the console
-- is sized by the gap left underneath it, recomputed on layout changes.
--
-- monitor.focused hands its handler the monitor being focused and fires before
-- the active-monitor pointer moves, so hl.get_active_monitor() still answers the
-- monitor being left (measured on this box: focusing eDP-1 from DP-11 reported
-- DP-11). Taking the argument when there is one is what stops a hop between
-- screens of different heights from sizing the console for the previous one.
local function fit(focused)
    local monitor = focused or hl.get_active_monitor()

    -- A monitor handle whose output has gone away answers nil to every field,
    -- and layout changes are exactly when that happens.
    if not monitor or not monitor.scale or monitor.scale <= 0 then
        return
    end

    -- Monitor dimensions are physical pixels; gaps are logical, so scale comes
    -- out before the (already logical) reserved area comes off.
    local reserved = monitor.reserved
    local usable = monitor.height / monitor.scale - reserved.top - reserved.bottom

    cover(math.max(0, math.floor(usable * (1 - share))))
end

-- Until a monitor can be read, cover the whole work area rather than leaving
-- the console unruled, so it is never seeded without its placement.
cover(0)
fit()

-- Only the focus hook names a monitor; discard whatever layout_changed passes so
-- fit() falls back to reading the active one there.
hl.on("monitor.layout_changed", function() fit() end)
hl.on("monitor.focused", fit)

-- The direction names the edge the offset is measured from: "slide top" drops
-- the console down into view, "slide bottom" retracts it back up.
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 3, bezier = "easeOutQuint", style = "slide top" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2, bezier = "easeInOutCubic", style = "slide bottom" })
