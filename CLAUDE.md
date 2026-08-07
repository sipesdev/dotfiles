# dotfiles — project guide

GNU Stow-managed dotfiles for a **Framework 16** (Ryzen AI 9 HX 370 / Radeon 890M) running
**Arch + Hyprland + Quickshell** — a "matte black" daily driver and the owner's primary machine.
Backed up to a private GitHub repo.

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
- `gtk`        → `~/.config/gtk-3.0`, `gtk-4.0` (matte-black GTK3/GTK4 overrides — see theming below)
- `qt`         → `~/.config/qt5ct`, `qt6ct`, `Kvantum` (Kvantum matte-black for Qt5/Qt6)
- `uwsm`       → `~/.config/uwsm/env`           (login-phase session env; **activates** the Qt theme)
- `alacritty`  → `~/.config/alacritty`          (matte-black terminal; `JetBrainsMono Nerd Font`, matches the Quickshell `Theme.qml` system font)

## Theming (`gtk/`, `qt/`, `uwsm/`) — matte black across toolkits
GTK apps use `adw-gtk3-dark` recolored to matte black by `gtk-3.0/gtk.css` + `gtk-4.0/gtk.css`
(`#121212` bg / `#bebebe` fg / `#e68e0d` accent). Qt apps use the **Kvantum** style (`MatteBlack`
theme) selected via `qt5ct`/`qt6ct`; the same palette drives `Kvantum/MatteBlack/MatteBlack.kvconfig`.
The Quickshell SNI tray context menus are native Qt `QMenu`s (see Quickshell note), so they follow the
Qt/Kvantum style — fixing Qt fixes the tray menus. What makes Qt actually load this: the env vars
`QT_QPA_PLATFORMTHEME=qt6ct` and `QT_STYLE_OVERRIDE=kvantum`, set in **both** `uwsm/env` (login-global)
and `hypr/modules/envs.lua` (in-session).
- **Kvantum owns the Qt palette; qt6ct is fonts/icons only.** `qt5ct/qt6ct.conf` set
  `custom_palette=false` + `style=kvantum` so the `MatteBlack` Kvantum theme is the single color
  source. Setting `custom_palette=true` layers qt6ct's `MatteBlack.conf` palette on top of Kvantum
  and produces "off" widget colors (wrong selection/disabled/menu tints) — don't re-enable it.
  (Omarchy themes Qt the same way: Kvantum-only via `QT_STYLE_OVERRIDE=kvantum`, no qt6ct palette.)
- **Do NOT edit via the qt6ct / Kvantum Manager GUIs.** Their atomic save replaces the stow symlink
  with a real file (silently de-stows it) and re-adds a volatile `[SettingsWindow]` geometry block to
  `qt6ct.conf`. Patch the repo files directly; if a GUI broke a link, re-`mv` the file in and `make stow`.
- The `MatteBlack` Kvantum theme is **vendored from [KvLibadwaita](https://github.com/GabePoel/KvLibadwaita)**
  (its `KvLibadwaitaDark` variant) — a libadwaita-style theme with flat widgets and rounded GTK-like
  menus. Earlier bases were rejected: `KvDark` was 3D/beveled; `KvGnomeDark` had blue baked into its
  SVG and non-rounded menus. Both `MatteBlack.svg` and `MatteBlack.kvconfig` are **real files** (not
  symlinks; self-contained, won't auto-update on `kvantum` upgrades) that were **recolored** from
  KvLibadwaita's mid-grey + blue to the matte `#121212` ramp + `#e68e0d` orange accent. The recolor
  is reproducible via `scratchpad/recolor.py` (single-pass regex hex remap of the SVG + kvconfig).
  KvLibadwaita is a user-space theme (no system package); it is NOT a dependency once vendored.
- **Reload:** GTK/Qt do **not** hot-reload — relaunch the app. New env vars need a **re-login** (or a
  Quickshell process restart for the tray menus); `hyprctl reload` is not enough.

## Hyprland (`hypr/`) — it's Lua, not hyprlang
This build is configured in **Lua**, not the usual `.conf`/hyprlang. `hyprland.lua` is the entry point; it
loads `modules/*.lua` by **absolute path via `loadfile()`** (plain `require("modules.x")` does not resolve
in this build — don't use it). Modules: `animations, autostart, bindings, envs, input, looknfeel, monitors,
windowrules`. The API surface (the `hl` global, `hl.bind`, `hl.dsp.*`) is described in the stub at
`/usr/share/hypr/stubs/hl.meta.lua` — consult it before guessing API shape. This applies to
`hyprctl dispatch` too: it evaluates its argument as Lua (`hyprctl dispatch 'hl.dsp.dpms("off")'`);
classic hyprlang forms like `hyprctl dispatch dpms off` fail to parse on this build. Also present:
`hypridle.conf`, `hyprlock.conf`, `hyprpaper.conf`, `wallpaper.sh`, `wallpapers/`.
**Reload:** `hyprctl reload`.

## Quickshell (`quickshell/`) — 0.3.0, hand-written QML
No `qmldir`. `Theme.qml`, `Sys.qml` and `Notifs.qml` are `pragma Singleton`, auto-resolved by filename.
`shell.qml` carries `//@ pragma UseQApplication` (required for native SNI tray context menus). `Sys.qml`
holds cross-component state (airplane mode mirrors `rfkill`; auto-brightness owns the `autobrightness`
process).

**Do not trust the hot reload.** Quickshell watches the *inode*, and an editor that saves atomically
(write temp + rename — which includes most tools) replaces it, so the watcher ends up on a deleted file:
the FIRST save reloads, every save after it is silently ignored and you are testing stale QML. Restart
instead, and verify:

    pkill -x quickshell; sleep 1; setsid nohup quickshell >/dev/null 2>&1 < /dev/null &

Verify with `quickshell log` (the running instance sends stdout/stderr to `/dev/null`, but logs persist on
disk): look for `Configuration Loaded` with no `error` lines after it — ignore the recurring
`dbus`/`StatusNotifierItem`/`portal` warnings, which are benign.

### Notifications (`Notifs.qml`) — Quickshell owns the bus, not mako
`Notifs.qml` is the notification daemon: it owns `org.freedesktop.Notifications`, caps every notification
at 8s, and holds arrivals while a popout is open. **Never leave that bus name unowned** — D-Bus then
returns `ServiceUnknown` and some apps abort rather than degrade, so any config error that stops Quickshell
loading also takes notifications down with it. Check with `busctl --user list | grep -i Notifications`.

mako is **uninstalled** (`pacman -Rns mako`), not merely masked. Masking was the interim step, and it was
needed because dropping mako's autostart line is not enough on its own: it shipped a D-Bus service file
claiming the same name, so the next `notify-send` would have activated it and it would have stolen the bus
back. Removing the package takes that file with it, which is what finally settles the question — so **do
not reinstall mako and leave it sitting there**, because an installed mako can always be activated into an
unowned bus.

Quickshell is therefore the only notification daemon on the box, and there is deliberately no fallback: if
it fails to load, notifications are down until it loads again. That is what makes a config error under
`quickshell/` more expensive than it looks — restart it and check the log (above) after any QML edit.

## Helper scripts (`localbin/`)
- `airplane-toggle` — mirrors the kernel's `rfkill` blanket toggle (`block all` / `unblock all`) so the
  Quickshell airplane button behaves identically to the hardware key. No per-radio save/restore by design.
- `autobrightness` — ALS-driven backlight. Does a one-shot read of `/sys/.../in_illuminance_raw` at start
  (because `monitor-sensor` only emits on change), then streams. Started/stopped by `Sys.autoBrightness`.
- `archwiki` — searches/renders the offline Arch Wiki (`arch-wiki-docs` package, mirror under
  `/usr/share/doc/arch-wiki/html/en`). `archwiki <query>` searches, `-t` titles only, `-r` renders an
  article to plain text via `python` (no lynx/w3m/pandoc on this box).
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
