-- ── Keybindings ───────────────────────────────────────────────────────
-- Convention:
--   SUPER + <key>            → Hyprland desktop / window controls
--   SUPER + SHIFT + <letter> → launch applications
--   SUPER + SHIFT + <num/arrow> → move the active window (no letter clash)

local mod = "SUPER"

-- Programs
local terminal = "alacritty"
local files    = "nautilus"
local browser  = "brave"
local launcher = "walker"

-- ── Applications (SUPER + SHIFT + letter) ─────────────────────────────
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd(terminal), { description = "Terminal" })
hl.bind(mod .. " + SHIFT + F", hl.dsp.exec_cmd(files),    { description = "Files" })
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd(browser),  { description = "Browser" })

-- ── Launcher ──────────────────────────────────────────────────────────
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd(launcher), { description = "App launcher" })

-- ── Window / desktop controls (SUPER) ─────────────────────────────────
hl.bind(mod .. " + Q", hl.dsp.window.close(),                  { description = "Close window" })
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
hl.bind(mod .. " + F", hl.dsp.window.fullscreen(),             { description = "Fullscreen" })
hl.bind(mod .. " + P", hl.dsp.window.pseudo(),                 { description = "Pseudo-tile" })
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"),           { description = "Toggle split" })

-- Logout / quit the session (window close = SUPER+Q; session quit = SUPER+CTRL+Q)
hl.bind(mod .. " + CTRL + Q", hl.dsp.exit(), { description = "Exit Hyprland" })

-- Lock
hl.bind(mod .. " + CTRL + L", hl.dsp.exec_cmd("loginctl lock-session"),
    { description = "Lock screen", locked = true })

-- Move focus
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces (SUPER + 1..0)
for i = 1, 10 do
    local key = i % 10 -- 10 → 0
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
end

-- Scratchpad (special workspace "magic")
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"), { description = "Toggle scratchpad" })

-- Cycle workspaces with the mouse wheel
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- ── Move the active window (SUPER + SHIFT + num/arrow) ─────────────────
for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Directional window move. NOTE: verify the arg shape on first run
-- (mirrors focus's "left/right/up/down"); swap to window.swap if needed.
hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- Move window to the scratchpad
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }),
    { description = "Send to scratchpad" })

-- ── Mouse: drag / resize floating windows ─────────────────────────────
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ── Screenshots (hyprshot → ~/Pictures + clipboard) ───────────────────
hl.bind("Print",           hl.dsp.exec_cmd("hyprshot -m region --freeze -o /home/michael/Pictures/Screenshots"))
hl.bind(mod .. " + Print", hl.dsp.exec_cmd("hyprshot -m window -o /home/michael/Pictures/Screenshots"))
hl.bind("SHIFT + Print",   hl.dsp.exec_cmd("hyprshot -m output -o /home/michael/Pictures/Screenshots"))

-- ── Color picker ──────────────────────────────────────────────────────
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Pick color" })

-- ── Media / brightness (laptop function keys) ─────────────────────────
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),       { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                    { locked = true, repeating = true })

-- ── Airplane mode ─────────────────────────────────────────────────────
-- The hardware airplane key (XF86RFKill / KEY_RFKILL) is handled DIRECTLY by the
-- kernel's built-in rfkill-input handler (CONFIG_RFKILL_INPUT=y) — it does a
-- blanket toggle of ALL radios on its own and cannot be intercepted here (the
-- kernel sees the key before Hyprland does). So there is intentionally NO bind for
-- it. The Quickshell airplane button runs ~/.local/bin/airplane-toggle, which
-- mirrors that same blanket toggle exactly — button and key are unified, no
-- save/restore, no desync. (Binding our own toggle here previously caused DOUBLE
-- handling: kernel + script fighting → the "kicks me off wifi" symptom.)

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
