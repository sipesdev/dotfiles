# dotfiles

Framework 16 · Arch · Hyprland · Quickshell — managed with [GNU Stow](https://www.gnu.org/software/stow/).

![Desktop — Hyprland + Quickshell, matte black](assets/screenshot.png)

## About
This is my personally managed dotfiles for my Arch Linux installation. It comes with my design dotfiles, GTK color overrides, my custom Kvantum theme, and a helper script for searching the local `arch-wiki-docs` for LLM searching.

## Packages
- `hypr`       → `~/.config/hypr`        (Hyprland Lua config)
- `quickshell` → `~/.config/quickshell`  (bar / control center)
- `localbin`   → `~/.local/bin`          (helper scripts; `wifi-connect` uses `zenity` for password prompts)
- `webapps`    → web2app PWA launchers + icons
- `shell`      → zsh/bash rc files
- `gtk`        → `~/.config/gtk-3.0`, `~/.config/gtk-4.0`  (matte-black GTK3/GTK4 overrides)
- `qt`         → `~/.config/{qt5ct,qt6ct,Kvantum}`         (Kvantum matte-black for Qt5/Qt6)
- `uwsm`       → `~/.config/uwsm/env`                      (login-phase env; activates the Qt theme)
- `alacritty`  → `~/.config/alacritty`                     (matte-black terminal; JetBrainsMono Nerd Font)

## Deploy on a new machine
```sh
sudo pacman -S --needed stow git zenity adw-gtk-theme papirus-icon-theme kvantum kvantum-qt5 qt5ct qt6ct hyprland quickshell
git clone git@github.com:sipesdev/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles && bash install.sh   # or: make stow
```

## License
Released under the [GNU General Public License v3.0](LICENSE).