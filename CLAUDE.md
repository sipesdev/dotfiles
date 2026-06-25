# dotfiles — project guide

GNU Stow-managed dotfiles for a **Framework 16** (Ryzen AI 9 HX 370 / Radeon 890M) running
**Arch + Hyprland + Quickshell** — a "matte black" daily driver. This is a separate machine from the
owner's Windows 11 primary. Backed up to a private GitHub repo.

## How Stow wiring works here (read this first)

Every package is stowed with `--no-folding --target=$HOME`, so each tracked file in `~/.config/...`,
`~/.local/...`, and `~/` is a **symlink into this repo**. A symlink is not a copy — the repo file and the
live config file are the **same inode**. Consequences:

- **Editing a file here is already live.** There is no "deploy" step for content edits. Do NOT run
  `make stow` after editing a file — the link already exists.
- **Edit files at the repo path** (`~/Projects/dotfiles/...`), not through the `~/.config/...` symlink.
  An editor that saves atomically (write temp + rename over) can replace the symlink with a plain file and
  silently break the stow link. Editing the real file in the repo avoids this.
- After editing, **reload the affected app** (see below) — saving updates the file, the app still needs to
  re-read it.

### When stow IS needed (structural changes only)
| Situation | Command |
|---|---|
| Fresh machine after `git clone` | `make stow` (or `bash install.sh`) |
| Added a **new file** to a package, or a **new package** | `make stow` |
| **Renamed / moved / deleted** repo files | `make restow` (prunes dead links) |
| Preview without changing anything | `stow -n -v <pkg>` |
| A real file is blocking a symlink | `stow --adopt <pkg>` |

`make` targets: `stow`, `restow`, `unstow`, `list`. `PKGS` lives in the `Makefile` — update it when adding
a package.

## Packages
- `hypr`       → `~/.config/hypr`              (Hyprland config — **Lua**, see below)
- `quickshell` → `~/.config/quickshell`        (bar + control center — Quickshell 0.3.0 QML)
- `localbin`   → `~/.local/bin`                (helper scripts)
- `webapps`    → `~/.local/share/applications` (web2app PWA `.desktop` launchers + `icons/`)
- `shell`      → `~`                            (`.zshrc`, `.zprofile`, `.bashrc`, `.bash_profile`)

## Hyprland (`hypr/`) — it's Lua, not hyprlang
This build is configured in **Lua**, not the usual `.conf`/hyprlang. `hyprland.lua` is the entry point; it
loads `modules/*.lua` by **absolute path via `loadfile()`** (plain `require("modules.x")` does not resolve
in this build — don't use it). Modules: `animations, autostart, bindings, envs, input, looknfeel, monitors,
windowrules`. The API surface (the `hl` global, `hl.bind`, `hl.dsp.*`) is described in the stub at
`/usr/share/hypr/stubs/hl.meta.lua` — consult it before guessing API shape. Also present:
`hypridle.conf`, `hyprlock.conf`, `hyprpaper.conf`, `wallpaper.sh`, `wallpapers/`.
**Reload:** `hyprctl reload`.

## Quickshell (`quickshell/`) — 0.3.0, hand-written QML
No `qmldir`. `Theme.qml` and `Sys.qml` are `pragma Singleton`, auto-resolved by filename. `shell.qml`
carries `//@ pragma UseQApplication` (required for native SNI tray context menus). `Sys.qml` holds
cross-component state (airplane mode mirrors `rfkill`; auto-brightness owns the `autobrightness` process).
**Hot-reloads on file save.** Verify a reload was clean with `quickshell log` (the running instance sends
stdout/stderr to `/dev/null`, but logs persist on disk): look for `Configuration Loaded` with no `error`
lines after it — ignore the recurring `dbus`/`StatusNotifierItem`/`portal` warnings, which are benign.

## Helper scripts (`localbin/`)
- `airplane-toggle` — mirrors the kernel's `rfkill` blanket toggle (`block all` / `unblock all`) so the
  Quickshell airplane button behaves identically to the hardware key. No per-radio save/restore by design.
- `autobrightness` — ALS-driven backlight. Does a one-shot read of `/sys/.../in_illuminance_raw` at start
  (because `monitor-sensor` only emits on change), then streams. Started/stopped by `Sys.autoBrightness`.
- `wifi-connect`, `web2app`, `web2app-remove`.

## Conventions
- **No emojis in any source file or comment** — hard rule, no exceptions.
- Match the existing style/formatting of the file you're editing; **patch the real file**, don't stack
  workarounds around it.
- Shell commands on this machine run under **zsh**: unquoted `$var` does **not** word-split — pass literal
  args (`stow ... hypr quickshell`) or use an array, not an unquoted list variable.

## Backup / secrets
Private GitHub repo; **PWAs only, no project source repos**. Only the named packages are stowed, and
`.gitignore` backstops secrets (`.env`, keys, `*_history`, caches). **Never commit tokens, keys, or
passwords** — scripts here read credentials at runtime (e.g. `wifi-connect` prompts via zenity), nothing is
hardcoded. Keep it that way.
