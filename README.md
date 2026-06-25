# dotfiles

Framework 16 · Arch · Hyprland · Quickshell — managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Packages
- `hypr`       → `~/.config/hypr`        (Hyprland Lua config)
- `quickshell` → `~/.config/quickshell`  (bar / control center)
- `localbin`   → `~/.local/bin`          (helper scripts)
- `webapps`    → web2app PWA launchers + icons
- `shell`      → zsh/bash rc files

## Deploy on a new machine
```sh
sudo pacman -S --needed stow git
git clone git@github.com:<you>/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles && bash install.sh   # or: make stow
```
