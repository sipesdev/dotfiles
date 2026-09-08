# dotfiles — project guide

GNU Stow-managed dotfiles for a **Framework 16** (Ryzen AI 9 HX 370 / Radeon 890M) running
**Arch + Hyprland + Quickshell** — a "matte black" daily driver and the owner's primary machine.
Backed up to a **public** GitHub repo (`github.com/sipesdev/dotfiles`).

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
- `doom`       → `~/.config/doom`, `~/.local/share/applications/emacs.desktop` (Doom Emacs private config + launcher entry; the framework is an untracked clone at `~/.config/emacs` — see Emacs below)
- `agents`     → `~/.agents/skills`             (cross-harness agent skills; `make agents-setup` links them into `~/.claude/skills`)
- `systemd`    → `~/.config/systemd/user`, `~/.config/environment.d` (crash-watch + emacs daemon units; the user-manager PATH; enabled once via `make agents-setup` / `make emacs-setup`)

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
- **LibreOffice** is pinned to the `gtk3` VCL backend (`SAL_USE_VCLPLUGIN=gtk3` in both env files) so it is
  a GTK3 app for theming purposes — its menus, dialogs and toolbars read the stowed `gtk-3.0/settings.ini`
  + `gtk.css`, nothing LibreOffice-side is configured. Nothing under `~/.config/libreoffice` is stowed:
  LibreOffice rewrites `registrymodifications.xcu` atomically and would de-stow it. Icon theme left on auto
  (Colibre Dark), no grammar checker — both by choice. Spellcheck/hyphenation are plain packages
  (`hunspell-en_us`, `hyphen-en`) found via the compiled-in `/usr/share/{hunspell,hyphen}` paths — nothing
  to enable.

## Hyprland (`hypr/`) — it's Lua, not hyprlang
This build is configured in **Lua**, not the usual `.conf`/hyprlang. `hyprland.lua` is the entry point; it
loads `modules/*.lua` by **absolute path via `loadfile()`** (plain `require("modules.x")` does not resolve
in this build — don't use it). Modules: `animations, autostart, bindings, envs, input, looknfeel, monitors,
qconsole, windowrules`. The API surface (the `hl` global, `hl.bind`, `hl.dsp.*`) is described in the stub at
`/usr/share/hypr/stubs/hl.meta.lua` — consult it before guessing API shape. This applies to
`hyprctl dispatch` too: it evaluates its argument as Lua (`hyprctl dispatch 'hl.dsp.dpms("off")'`);
classic hyprlang forms like `hyprctl dispatch dpms off` fail to parse on this build. Also present:
`hypridle.conf`, `hyprlock.conf`, `hyprpaper.conf`, `wallpaper.sh`, `wallpapers/`.
- `modules/qconsole.lua` — the Quake agent console: `SUPER+grave` toggles the dimmed special workspace
  `special:console`, seeded on first open with `agent --inline` (class `agent-console`). It is **tiled**
  and sized by the workspace's bottom gap (top half of the usable area), recomputed on monitor focus and
  layout changes; a window rule would freeze that size at map time, so don't reach for one.
- `SUPER+SHIFT+A` runs `~/.local/bin/agent`, whose terminal (class `agent-tui`) the `float-agent-tui` rule
  floats and centers at 60% x 60% — a different class from the console precisely so it is not floated.

**Reload:** `hyprctl reload`.

## Quickshell (`quickshell/`) — 0.3.0, hand-written QML
No `qmldir`. `Theme.qml`, `Sys.qml` and `Notifs.qml` are `pragma Singleton`, auto-resolved by filename.
`shell.qml` carries `//@ pragma UseQApplication` (required for native SNI tray context menus). `Sys.qml`
holds cross-component state (ethernet/Wi-Fi hand-off, native NetworkManager and BlueZ state; auto-brightness owns the `autobrightness`
process).

**Do not trust the hot reload.** Quickshell watches the *inode*, and an editor that saves atomically
(write temp + rename — which includes most tools) replaces it, so the watcher ends up on a deleted file:
the FIRST save reloads, every save after it is silently ignored and you are testing stale QML. Restart
instead, and verify:

    pkill -x quickshell; sleep 1; setsid nohup quickshell >/dev/null 2>&1 < /dev/null &

Verify with `quickshell log` (the running instance sends stdout/stderr to `/dev/null`, but logs persist on
disk): look for `Configuration Loaded` with no `error` lines after it — ignore the recurring
`dbus`/`StatusNotifierItem`/`portal` warnings, which are benign.

### Bar modules (`BarDrawer` / `BarIcon`)
The right cluster is one pill per module (`BarIcon`; `Battery.qml` for power) and one drawer per
module: `BluetoothDrawer`, `NetworkDrawer`, `AudioDrawer`, `DisplayDrawer`, `PowerDrawer`, `AgentsDrawer`, all
`BarDrawer { barWindow: bar; key: "<name>"; anchorItem: <pill> }`. `BarDrawer.qml` owns the
popout shell (welded under the bar, `reveal` slide, `DrawerShadow`, focus grab); `Bar.qml` owns
arbitration: `openPopout` holds the open key, pills call `togglePopout(key)`, a drawer's grab
calls `closePopout(key)`, and a drawer is `shown` exactly while `openPopout === key` (never write
`shown`). The bar window is inside every grab so pill clicks never clear it. `Sys.qml` exposes the
native NetworkManager / BlueZ state (`wifiDevice`, `wifiNetwork`, `wifiStrength`, `btAdapter`,
`btConnected`) that both the pills and drawers read, owns Bluetooth power (`setBluetoothPower`, via the
rfkill soft block so the choice survives a reboot) and the one discovery session every monitor's Bluetooth
drawer shares (`btDrawersOpen`, `btOwesDiscoveryStop`: scan only while a drawer is open, stopped after
close against BlueZ's confirmed state). It also owns the agents usage records (one `AgentRecord.qml`
`FileView` per file under `~/.local/state/agents/usage/`, the 900 s `agent-usage-update` poller, a 30 s
retry when a collector advises one, and `launchAgentTerminal()`); the agents pill is **hidden** unless some
record reports `ready`, and right-clicking it launches the agent terminal. Primitives: `DrawerHero`,
`SectionHeader`, `ListRow`, `SliderRow`, `TogglePill`/`ToggleRow`, `Pill`, `PowerBtn`, `BarSlider`. Logic
that can be pure lives in `NetModel.js` / `AudioModel.js` / `PowerModel.js` / `BtModel.js` /
`AgentModel.js` / `ListSync.js` (in-place `ListModel` updates, so list delegates and their hover survive a
refresh) and is tested by `make test` — node over `tests/quickshell/`, python over `tests/agents/` (the
collectors' pure functions); both trees sit deliberately outside every stow package. The network drawer
polls `~/.local/bin/network-probe` (1.5 s) only while open; the agents drawer asks Sys for a
`--limits-only` refresh when it opens and a `--force` one from its header refresh button (dimmed, and a
no-op, while an update is already running).

### Notifications (`Notifs.qml`) — Quickshell owns the bus, not mako
`Notifs.qml` is the notification daemon: it owns `org.freedesktop.Notifications`, caps Normal and Low
notifications at 8s, and holds arrivals while a popout is open. **Critical urgency is exempt from the
cap** — a critical card never starts its countdown and stays until clicked or dismissed (overflow past the
5 visible cards is the escape valve that stops the stack jamming). Two senders go critical: `crash-watch`,
whose sticky toast is the click target, and `/usr/bin/uwsm-app`, which sends one when an app fails to launch
(`agent` starts through it) — sticking is right for both. **Never leave that bus name unowned** — D-Bus then
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
A restart also drops any *pending* crash toast: `crash-watch`'s `notify-send` is blocked waiting for the
click and exits actionless when the server goes away. Accepted failure mode; the recovery is to run
`agent-crash <pid>` by hand against the PID in `coredumpctl list`.

## Helper scripts (`localbin/`)
- `backlight` — the only writer of the panel backlight: `get` / `set N` (linear, 0-100 of the safe
  range; the Display drawer), `up` / `down` (the brightness keys; exponential steps as before),
  `set-exp N` (autobrightness). Caps at 98% of `max_brightness` because `amdgpu_bl1` goes dark
  (`actual_brightness` 0) from raw ~64880 up; "100" is the brightest the panel actually reaches.
- `bluetooth-power` — `on` / `off` via `rfkill unblock|block bluetooth` (BlueZ's Powered is not persisted;
  the block is). `on` waits for `Powered: yes`, falling back to `bluetoothctl power on`. Explicit
## Emacs (`doom/`, `systemd/`) — Doom Emacs on a per-session daemon
`emacs-wayland` (pgtk, native-comp) running **Doom Emacs**. The framework is an **untracked** shallow clone
of `doomemacs/core` at `~/.config/emacs` (its `doom` CLI is on PATH via `.zshrc`/`.bashrc`); only the
private config is tracked, as the stowed `doom` package → `~/.config/doom/{init,config,packages}.el`.
`doom sync` after editing `init.el` or `packages.el`; `config.el` edits need only a daemon restart
(`systemctl --user restart emacs.service`) or `M-x doom/reload`; `doom upgrade` updates framework and
packages; `doom doctor` when something is off. `config.el` sets `doom-font` to `JetBrainsMono Nerd Font`
11pt (the alacritty / `Theme.qml` font); the theme is `matte-black`
(`doom/.config/doom/themes/matte-black-theme.el`, derived from doom-one with the `alacritty.toml` palette
— change a color in one, change it in the other). Emacs writes through the stow symlinks (no atomic
rename), but edit at the repo path anyway and run `stow-doctor` if a link looks stale.
- **Daemon:** `systemd/.config/systemd/user/emacs.service` shadows the vendor unit so it is
  `WantedBy=`/`PartOf=graphical-session.target` — it starts after uwsm has exported the session env
  (`WAYLAND_DISPLAY`, the Qt/GTK vars) and stops at logout, like `crash-watch`. Enabled once via
  `make emacs-setup`. No Doom envvar file (`doom install --no-env`): the daemon inherits the systemd
  user manager's environment, which `environment.d/10-path.conf` gives the shells' PATH prefix
  (`~/.local/bin`, `~/.config/emacs/bin`) and uwsm/env the rest of the session variables.
- **Editor:** `EDITOR`/`VISUAL` are `emacsclient -t` (login copy in `uwsm/env`, in-session copy in
  `modules/envs.lua`), so `git commit` and the `.zsh_agents` editor panes (`${EDITOR:-nvim} .`) open a terminal
  frame on the daemon. `SUPER+SHIFT+E` opens an Alacritty running `emacsclient -t -a ''` (terminal Emacs is the default
  everywhere; `emacsclient -c` still gives a GUI frame; `-a ''` starts a daemon if the unit is down).
- **Terminal first, GUI-identical.** `emacs` in a shell is aliased to `emacsclient -t -a ''` and the
  launcher's "Emacs" entry (`doom/.local/share/applications/emacs.desktop`, shadowing the vendor one; "Emacs
  (Client)" stays the GUI entry) runs the same Alacritty command as `SUPER+SHIFT+E`; Alacritty is truecolor
  and uses the same Nerd Font, so a terminal frame paints the theme's exact colors (the unit exports
  `COLORTERM=truecolor`: Emacs sizes a tty frame's palette from the daemon's environment, not the client's,
  and without it `emacsclient -t` is 256-color), shows the modeline icons (`doom-modeline-icon t`) and, on
  Emacs 31, gets child-frame popups. `:os tty` gives it mouse, cursor shapes and OSC 52 clipboard. Terminal
  frames keep the terminal's own background (`+matte/tty-transparent-bg` in `config.el`) so Alacritty's
  opacity shows through; solaire-mode is disabled in `packages.el`, so the dashboard, popups and sidebars
  keep that same background instead of `bg-alt` (an opaque darker block in terminal frames otherwise).

  direction only.
- `autobrightness` — ALS-driven backlight. Does a one-shot read of `/sys/.../in_illuminance_raw` at start
  (because `monitor-sensor` only emits on change), then streams. Started/stopped by `Sys.autoBrightness`.
  Applies levels via `backlight set-exp`.
- `archwiki` — searches/renders the offline Arch Wiki (`arch-wiki-docs` package, mirror under
  `/usr/share/doc/arch-wiki/html/en`). `archwiki <query>` searches, `-t` titles only, `-r` renders an
  article to plain text via `python` (no lynx/w3m/pandoc on this box).
- `network-probe` — default-route interface snapshot (iface/ip/gateway/rx/tx bytes + a 1.1.1.1 ping) as
  `key\tvalue` lines; nothing when there is no route.
- `agent` — launches the default coding agent auto-approved: the harness named in `~/.config/agent/default`,
  else the first of claude/codex/gemini on `PATH`. `--inline` stays in the current terminal, `--prompt "..."`
  seeds the first message; otherwise it opens a floating alacritty (class `agent-tui`, see the window rule).
  It does **not** `cd` anywhere — launching from `$HOME` starts the agent in `$HOME` (by request; Omarchy
  hopped to `~/Projects` to dodge the harness's workspace-trust prompt, an accepted trade-off here).
- `agent-crash` — `agent-crash <pid> [name] [exe] [signal]`: turns a coredump PID into an AI diagnosis. Adds
  the `coredumpctl` timestamp, `cd`s to this repo (the only place the agent may fix) and points it at the
  `diagnose-crash` skill. Runnable by hand against any PID in `coredumpctl list`.
- `crash-watch` — follows the journal for systemd-coredump entries (run by `crash-watch.service`) and raises
  one sticky critical toast per program per 60 s for *this user's* crashes; clicking it runs `agent-crash`.
  Waits for the notification bus first, so a quickshell crash still announces itself once the shell is back.
- `agent-usage-update` + `agent-usage-{claude,codex,gemini}` — usage records for the agents pill/drawer, one
  JSON file per agent at `~/.local/state/agents/usage/<id>.json` (written atomically; `--force` bypasses the
  scan and probe caches, `--limits-only` is accepted for CLI parity but the incremental transcript scan is
  cheap enough to run anyway). A collector prints **nothing** when its CLI is absent, and the updater then
  deletes the stale record so the pill self-hides — adding an agent is adding a collector. The claude
  collector reads `~/.claude/.credentials.json` at runtime; the token rides in the `Authorization` header
  only and is never printed, logged, or written into the record. Codex/gemini are ported but unverified —
  neither CLI is installed here, so nothing below their absent-CLI gate has ever run.
- `web2app`, `web2app-remove`.

## Shell (`shell/`) — agent workspace layouts
`.zshrc` sources `.zsh_agents`, the layout helpers ported from Omarchy Quattro: herdr splits `hdl` / `hds` /
`hdlm` / `hsl`, their tmux twins `tdl` / `tds` / `tdlm` / `tsl`, and the alias `a` = `agent --inline`. Every
function opens with `emulate -L ksh` so the upstream bash (0-based arrays, word splitting) ports verbatim —
keep that line if you edit one. One deliberate divergence: `hdl`/`hds` end the editor pane's command with
`; exec ${SHELL:-zsh}` so quitting the editor drops to a shell instead of tearing the pane down (the tmux
twins type into a persistent shell already and need no such thing). herdr is not installed here and no
layout has been run end to end; panes that start optional tools (hunk, opencode) just print
command-not-found.

## Conventions
- **No emojis in any source file or comment** — hard rule, no exceptions.
- Match the existing style/formatting of the file you're editing; **patch the real file**, don't stack
  workarounds around it.
- Shell commands on this machine run under **zsh**: unquoted `$var` does **not** word-split — pass literal
  args (`stow ... hypr quickshell`) or use an array, not an unquoted list variable.

## Backup / secrets
**Public** GitHub repo (`sipesdev/dotfiles`, verified `gh repo view --json visibility` 2026-08-21) —
everything committed is world-readable: file contents, commit messages, PR bodies and review threads.
Fully-qualified issue references (`owner/repo#N`, or the full URL) in a PR body, commit message, or
comment autolink and post a permanent public "mentioned this" event on the upstream issue's timeline
(PR #7 did this on `hyprwm/aquamarine#324` and `#316`; such events cannot be removed afterwards). Default
to the non-linking forms — a code span (`` `hyprwm/aquamarine#324` ``) or the bare `aquamarine#324` — and
use the autolinking form only when the mention is deliberately meant for upstream. **PWAs only, no project
source repos**. Only the named packages are stowed, and `.gitignore` backstops secrets (`.env`, keys,
`*_history`, caches). **Never commit tokens, keys, or passwords** — scripts here read credentials at
runtime (the Network drawer's inline prompt hands a Wi-Fi key to NetworkManager through Quickshell's
`connectWithPsk`, never on a command line), nothing is hardcoded. Keep it that way.
- **System files (`etc/`)** are not stowed: `make dns` installs `etc/NetworkManager/conf.d/20-dns.conf`
  with sudo (Cloudflare global DNS, no switcher by design); verify with `grep nameserver /etc/resolv.conf`.
