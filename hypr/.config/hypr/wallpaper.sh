#!/usr/bin/env bash
# Reliable hyprpaper wallpaper setter (IPC auto-loads; retries until ready).
wp="/home/michael/.config/hypr/wallpapers/1-dark-waters.jpg"
mon="${1:-eDP-1}"
for i in $(seq 1 40); do
  hyprctl hyprpaper wallpaper "${mon},${wp}" >/dev/null 2>&1 && exit 0
  sleep 0.25
done
exit 1
