-- ── Look & feel ───────────────────────────────────────────────────────
-- Matte Black, material-rounded: rounded corners, blur + shadow,
-- orange accent borders (#e68e0d).

local accent          = "rgb(e68e0d)"      -- matte-black accent (orange)
local inactive_border = "rgba(595959aa)"   -- muted gray

hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 2,

        col = {
            active_border   = accent,
            inactive_border = inactive_border,
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 10,  -- rounded window corners
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 0.80,  -- inactive windows translucent (frosted via blur below)
        dim_inactive     = true,  -- faint dark cue only; kept low so inactive windows stay readable
        dim_strength     = 0.05,

        shadow = {
            enabled      = true,
            range        = 12,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },

        blur = {
            enabled           = true,
            size              = 3,
            passes            = 1,     -- was 2; halves per-frame blur cost to keep the eGPU cool on the idle desktop
            ignore_opacity    = false, -- was true (frosted glass through inactive windows); off = don't re-blur translucent windows every frame
            new_optimizations = true,
            vibrancy          = 0.1696,
        },
    },

    misc = {
        force_default_wallpaper = 0,            -- no anime mascot
        disable_hyprland_logo   = true,
        background_color        = "rgb(121212)", -- matte black behind windows
    },

    dwindle = {
        preserve_split = true,
    },
})
