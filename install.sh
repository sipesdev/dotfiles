#!/usr/bin/env bash
# Deploy these dotfiles on a fresh machine: clone, then `bash install.sh`.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
command -v stow >/dev/null || { echo "Install stow first: sudo pacman -S --needed stow"; exit 1; }
make stow
echo "Done. Restart Hyprland / Quickshell to pick up the configs."
