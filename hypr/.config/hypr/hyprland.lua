-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Hyprland — modular Lua config (Framework 16, matte black)          ║
-- ║  Entry point. Loads ~/.config/hypr/modules/*.lua by ABSOLUTE path   ║
-- ║  via loadfile(). plain require("modules.x") does NOT resolve to     ║
-- ║  ~/.config/hypr/modules/ in this build, so we avoid it entirely.    ║
-- ║  API reference for THIS build: /usr/share/hypr/stubs/hl.meta.lua    ║
-- ╚══════════════════════════════════════════════════════════════════╝

local home = (os and os.getenv and os.getenv("HOME")) or "/home/michael"
local dir  = home .. "/.config/hypr/"

local function load(file)
    local chunk, err = loadfile(dir .. file)
    if chunk then
        chunk()
    else
        print("[hypr config] failed to load " .. file .. ": " .. tostring(err))
    end
end

load("modules/monitors.lua")     -- displays
load("modules/envs.lua")         -- environment variables (Wayland, AMD)
load("modules/input.lua")        -- keyboard / touchpad / gestures
load("modules/looknfeel.lua")    -- general / decoration / misc (matte black)
load("modules/animations.lua")   -- curves + animation tree
load("modules/windowrules.lua")  -- window rules
load("modules/bindings.lua")     -- keybinds
load("modules/autostart.lua")    -- launched once on session start
