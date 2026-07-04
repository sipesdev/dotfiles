#!/usr/bin/env bash
# Reliable hyprpaper wallpaper setter across ALL connected monitors.
#
# hyprpaper IPC auto-loads the preload; we set the wallpaper on every monitor
# Hyprland reports. At boot the eGPU (OCuLink) DisplayPort outputs register a
# beat after the internal panel, so with no args we first wait for the monitor
# set to settle (docked = panel + >=1 external, via EGPU_PRESENT), then set
# each -- adapting to docked/mobile with no reconfiguration. Explicit monitor
# args skip the wait and target just those outputs.
set -u
wp="/home/michael/.config/hypr/wallpapers/1-dark-waters.jpg"

if [ "$#" -gt 0 ]; then
    mons=("$@")
else
    # Wait for the monitor set to settle before enumerating.
    min=1
    [ "${EGPU_PRESENT:-0}" = "1" ] && min=2
    prev=-1 stable=0
    for _ in $(seq 1 48); do              # ~12s ceiling
        n=$(hyprctl monitors 2>/dev/null | grep -c '^Monitor ')
        if [ "$n" -ge "$min" ] && [ "$n" = "$prev" ]; then
            stable=$((stable + 1)); [ "$stable" -ge 8 ] && break
        else
            stable=0
        fi
        prev=$n; sleep 0.25
    done
    mapfile -t mons < <(hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2}')
fi

# hyprpaper may still be preloading at startup; retry each set until it sticks.
rc=1
for mon in "${mons[@]}"; do
    for _ in $(seq 1 40); do
        hyprctl hyprpaper wallpaper "${mon},${wp}" >/dev/null 2>&1 && { rc=0; break; }
        sleep 0.25
    done
done
exit "$rc"
