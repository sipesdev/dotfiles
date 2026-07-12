-- ── Autostart ─────────────────────────────────────────────────────────
-- Runs ONCE when the compositor starts (not on every config reload).
-- Apps are launched directly; the session itself is started by uwsm,
-- so env + portals are already set up. (Per-app `uwsm app --` scoping
-- can be added later if desired.)

local home = os.getenv("HOME")

hl.on("hyprland.start", function()
    -- Wallpaper: start hyprpaper, then set via IPC (conf alone races the
    -- 4K preload at startup on this build; the IPC setter retries until ready).
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd(home .. "/.config/hypr/wallpaper.sh")

    -- Status bar + control center (Quickshell). qs-start waits for the eGPU's
    -- external outputs to register before launching -- starting too early
    -- leaves blank, non-painting bars on the external monitors.
    hl.exec_cmd(home .. "/.local/bin/qs-start")

    -- Idle / lock management
    hl.exec_cmd("hypridle")

    -- Block lid-close / suspend-key sleep while the OCuLink eGPU is docked
    -- (s2idle resume drops it off the PCIe bus and crashes the machine). No-op
    -- when undocked. Pairs with egpu-suspend-guard on hypridle's idle timer.
    hl.exec_cmd(home .. "/.local/bin/egpu-suspend-inhibit")

    -- PolicyKit authentication agent (GNOME)
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- Bluetooth pairing agent (bluez-tools). Quickshell's Bluetooth module talks
    -- to BlueZ but registers no Agent1, so pairing new devices from the quick
    -- settings menu needs an external agent. NoInputNoOutput = just-works auto-accept.
    hl.exec_cmd("bt-agent --capability=NoInputNoOutput")

    -- Clipboard history daemon (cliphist)
    hl.exec_cmd("wl-paste --type text  --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- App launcher: Elephant backend (idempotent) + Walker service (open with `walker`)
    hl.exec_cmd("systemctl --user start elephant.service")
    hl.exec_cmd("walker --gapplication-service")
end)
