---
name: dotfiles
description: >
  How this machine's desktop and system configuration works and how to change
  it safely. Use for ANY request to customize or debug the desktop: Hyprland
  (keybinds, gaps, window rules, monitors, animations), the Quickshell bar,
  drawers, or notifications, GTK/Qt theming, the terminal (alacritty),
  backlight, audio, Wi-Fi/Bluetooth behavior, or helper scripts in ~/.local/bin.
---

# This machine's configuration

Framework 16 (Ryzen AI 9 HX 370 / Radeon 890M), Arch Linux, Hyprland on
Wayland, Quickshell 0.3 bar/shell, zsh. ALL configuration lives in the GNU
Stow repo at `~/Projects/dotfiles`, symlinked with `stow --no-folding`, so:

- **Edit files at the repo path** (`~/Projects/dotfiles/...`), never through
  the `~/.config/...` symlink -- an atomic save through the symlink silently
  de-stows it.
- **Content edits are live immediately** (same inode). There is no deploy
  step; do NOT run `make stow` after editing an existing file.
- **NEW files or packages need `make stow`**; renames/deletions need
  `make restow`. The package list is `PKGS` in the `Makefile`.
- After editing, reload the affected app (below) -- nothing hot-reloads
  reliably.

## Hyprland -- it's Lua, not hyprlang

`hypr/.config/hypr/hyprland.lua` loads `modules/*.lua` by absolute path via
`loadfile()` (plain `require` does not resolve). The API surface (`hl` global:
`hl.bind`, `hl.dsp.*`, `hl.window_rule`, `hl.config`, ...) is documented in
the stub at `/usr/share/hypr/stubs/hl.meta.lua` -- consult it before guessing.
`hyprctl dispatch` also evaluates Lua (`hyprctl dispatch 'hl.dsp.dpms("off")'`);
classic hyprlang forms fail to parse. Reload: `hyprctl reload`.

## Quickshell -- restart, never trust the hot reload

The bar, drawers, and the NOTIFICATION DAEMON are hand-written QML under
`quickshell/.config/quickshell/`. After any QML edit:

    pkill -x quickshell; sleep 1; setsid nohup quickshell >/dev/null 2>&1 </dev/null &

then check `quickshell log` for `Configuration Loaded` with no error lines
after it. `Notifs.qml` owns org.freedesktop.Notifications: a QML error takes
desktop notifications down for every app until fixed. Pure list/format logic
lives in `*.js` models tested by `make test`.

## Helper scripts

`~/.local/bin` (stowed from `localbin/`): `backlight` (the ONLY backlight
writer), `bluetooth-power`, `autobrightness`, `network-probe`, `archwiki`
(offline Arch Wiki search), `agent` (launch the default coding agent),
`agent-crash`, `crash-watch`, `agent-usage-update` plus per-agent collectors.

## Hard rules

- No emojis in any source file or comment.
- The repo is PUBLIC: never commit tokens, keys, or passwords. Credentials are
  read at runtime only and never printed or logged.
- Never file or comment on upstream issues/PRs; cite issues as code spans
  (`owner/repo#N`), never as autolinking references.
- Match the existing style of the file being edited; patch the real file
  rather than stacking workarounds.
- The interactive shell is zsh (unquoted `$var` does not word-split).
