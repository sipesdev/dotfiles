# System changes outside the stow packages

A record of changes to root-owned system state this repo does not track (`/etc`, `/usr`, the ESP,
NVRAM, firmware). Tracked root config lives in `etc/` and is applied by `make dns`; it is listed here
only for completeness. Everything else was changed in place, so this log is the only history. Add an
entry for every such change, newest first: what changed, why, how it was applied and verified, and
how to undo it. Package installs are in `/var/log/pacman.log` and appear here only where they came
with a configuration change.

Entries before 2026-10-17 were reconstructed on 2026-10-17 from the archinstall log
(`/var/log/archinstall/install.log`), the journal's sudo log (`journalctl _COMM=sudo -g COMMAND=`),
the scripts in `~/setup/`, `/var/log/pacman.log`, `/var/log/cups/access_log`, file timestamps and
notes kept from the June setup sessions, then fact-checked against the same sources. All times are
local (UTC-7). Changes made from a root shell, through pkexec or polkit, or in a GUI do not appear
in the sudo log: the printer queue was added in system-config-printer through cups-pk-helper, and
btrfs-assistant ran as root through pkexec on 2026-06-23 and 2026-09-14 with no record of what it
changed. Those entries may be incomplete.

## Current state

| Path | Role | Changed |
|---|---|---|
| `/etc/mkinitcpio.conf.d/snapshots.conf` | The effective `HOOKS` line: drop-ins are sourced after `/etc/mkinitcpio.conf`, so the `HOOKS` there is dead. Adds `btrfs-overlayfs` so read-only snapshots boot writable. | 2026-06-23, 2026-10-17 |
| `/etc/mkinitcpio.conf.d/gpu.conf` | `MODULES` for early KMS on both GPUs | 2026-10-17 |
| `/etc/mkinitcpio.conf` (edited) | Install-time `HOOKS` (`udev`, `keymap`, `consolefont` and `encrypt` in place of the shipped systemd hooks), then `plymouth` added; overridden by `snapshots.conf` | 2026-06-22, 2026-06-23 |
| `/etc/mkinitcpio.d/linux.preset` | Rewritten 2026-06-23; gone since 2026-06-30, when mkinitcpio's remove hook moved the edited preset to `linux.preset.pacsave` during a kernel upgrade. `limine-mkinitcpio` builds the images without one. | 2026-06-23, 2026-06-30 |
| `/etc/default/limine` | limine-entry-tool settings; generates `/boot/limine.conf` and the UKI | 2026-06-23 |
| `/etc/kernel/cmdline` | Kernel command line written at install, `quiet splash` added; same text as `KERNEL_CMDLINE` in `/etc/default/limine`, which is the one limine-entry-tool reads | 2026-06-22, 2026-06-23 |
| `/etc/snapper/configs/root`, `/etc/conf.d/snapper` (edited) | Snapper as archinstall set it up, reworked to a root-only config tuned for snap-pac | 2026-06-22, 2026-06-23 |
| `/etc/systemd/system/getty@tty1.service.d/autologin.conf` | Autologin on tty1 | 2026-06-23 |
| `/etc/systemd/system/*.wants/` | Units enabled by hand: `limine-snapper-sync` (2026-06-23), `nvidia-suspend`/`-hibernate`/`-resume` (2026-07-03), `avahi-daemon` (2026-08-05); `snapper-timeline.timer` disabled (2026-06-23). cups, ufw, bluetooth, NetworkManager, power-profiles-daemon, timesyncd and `snapper-cleanup.timer` were enabled by archinstall. | 2026-06-23 to 2026-08-05 |
| `/etc/systemd/systemm/` | Empty, left by a mistyped `mkdir`; harmless | 2026-06-23 |
| `/etc/plymouth/plymouthd.conf` (edited), `/usr/share/plymouth/themes/arch-matte/` | Boot splash theme | 2026-06-23 |
| `/etc/NetworkManager/conf.d/wifi_backend.conf` | Written at install with `wifi.backend=iwd`; switched to `wifi.backend=wpa_supplicant` | 2026-06-22, 2026-06-23 |
| `/etc/NetworkManager/conf.d/20-dns.conf` | Cloudflare DNS; tracked in `etc/`, applied by `make dns` | 2026-08-24 |
| `/etc/bluetooth/main.conf` (edited) | `AutoEnable=false` | 2026-06-23 |
| `/usr/share/icons/Papirus*` | Folder icons recoloured orange by `papirus-folders` | 2026-06-23 |
| `/etc/modprobe.d/nvidia-power.conf` | `options nvidia NVreg_PreserveVideoMemoryAllocations=1` | 2026-07-03 |
| `/etc/group` (edited) | `michael` in `gamemode` (2026-07-03) and `docker` (2026-07-13), besides `wheel` from the install | 2026-07-03, 2026-07-13 |
| `/etc/ufw/ufw.conf`, `/etc/ufw/user.rules`, `/etc/ufw/user6.rules` (edited) | Firewall enabled; extra inbound rules | 2026-07-26 to 2026-10-05 |
| `/etc/cups/printers.conf`, `/etc/cups/ppd/Epson-WF-3640.ppd` | Epson WF-3640 queue, the default printer (cupsd also maintains `printcap`, `classes.conf` and `subscriptions.conf`) | 2026-08-05 |
| `/etc/docker/daemon.json`, `/etc/containerd/config.toml` | Docker and containerd data on the external Repos drive | 2026-09-03, 2026-09-07 |
| `/etc/pacman.conf` (edited) | `Color` and `[multilib]` from the install, `ILoveCandy` by hand (`ParallelDownloads = 5` is pacman's shipped default) | 2026-06-22 |
| `/etc/pacman.d/hooks/99-limine.hook` | From archinstall: copies `BOOTX64.EFI`/`BOOTIA32.EFI` to the ESP fallback path after a limine upgrade | 2026-06-22 |
| `/etc/fstab` (edited), `/etc/locale.gen` (edited), `/etc/systemd/zram-generator.conf`, `/etc/X11/xorg.conf.d/00-keyboard.conf` | From the install | 2026-06-22 |
| ESP `/boot/limine/limine.conf.disabled`, `/boot/EFI/Linux/arch-linux.efi` | The install's Limine config, demoted, and the kernel 7.0.12 UKI it boots (hyphen; the live UKI is `arch_linux.efi`). Not a working recovery path: no matching modules. | 2026-06-23 |
| NVRAM | Boot0004 deleted; `Limine` entry added by `limine-install` | 2026-06-23 |

Pending `.pacnew` merges, not yet applied: `/etc/bluetooth/main.conf.pacnew` (adds a
`[ChannelSounding]` section; keep `AutoEnable=false` when merging), `/etc/locale.gen.pacnew` (keep
`en_US.UTF-8 UTF-8` uncommented when merging), and the two
`/etc/tpm2-tss/fapi-profiles/*.json.pacnew`.

## 2026-10-17: LUKS prompt on every monitor (early KMS for both GPUs)

**Why.** Plymouth draws the LUKS passphrase prompt only on GPUs whose DRM driver is running in the
initramfs. Only amdgpu was there (through the `kms` hook), so the prompt appeared on eDP-1 alone,
the panel that stays off while docked; nvidia-drm loaded after the root switch. The `kms` hook with
`autodetect` also packed nouveau into the UKI, plus about 106M of its GSP firmware, although
nvidia-utils blacklists it. The eGPU is OCuLink on root port `00:03.3`, not Thunderbolt, so no bolt
authorisation is involved.

**Change.**

- `snapshots.conf`: `kms` removed from `HOOKS`.

  ```diff
  -HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)
  +HOOKS=(base udev plymouth autodetect microcode modconf keyboard keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)
  ```

- `gpu.conf` (new). amdgpu is listed explicitly because the `kms` hook no longer adds it, and it
  must stay in the image for the panel to get the prompt with the eGPU unplugged.

  ```sh
  MODULES=(amdgpu nvidia nvidia_modeset nvidia_uvm nvidia_drm)
  ```

- Rebuilt with `sudo limine-mkinitcpio`: `/boot/EFI/Linux/arch_linux.efi` went from 180M to 160M
  (nouveau and its firmware out, about 86M of nvidia modules and GSP firmware in).

**Applied by** `~/setup/egpu-early-kms.sh` (outside this repo). It backed up `snapshots.conf`,
`/boot/limine.conf` and the old UKI to `~/boot-backup-2026-10-17-0120/`, then gated on the resolved
`HOOKS`/`MODULES`, the new initramfs contents (nvidia modules and firmware, amdgpu, Plymouth,
cryptsetup present; nouveau absent), an unchanged `.cmdline`, and the BLAKE2 hash `limine.conf` pins
for the UKI. Any failed gate restores the old config and rebuilds.

**Verified.**

- Docked: the prompt shows on DP-11, DP-9 and eDP-1. `journalctl -b -k` shows
  `Initialized amdgpu` and `Initialized nvidia-drm` before systemd starts in the real root.
- Undocked (powered off before unplugging OCuLink, which is not hot-pluggable): the prompt shows on
  eDP-1, and nvidia logs `NVRM: No NVIDIA GPU found.` harmlessly. The session comes up iGPU-only
  (`AQ_DRM_DEVICES` lists the AMD card only, no NVIDIA env vars, eDP-1 at 2560x1600@165).

**Side effects.**

- Docked, the prompt appears about 1.7 s later: the initramfs now waits for the NVIDIA GSP firmware
  to boot before Plymouth starts. Undocked there is no delay.
- Undocked, Hyprland's log gains `eglQueryDevicesEXT ... EGL_BAD_ALLOC` lines from NVIDIA's EGL
  vendor library finding no card. Rendering is unaffected.
- nvidia-open and nvidia-utils upgrades rebuild the UKI through the existing pacman hook
  (`/etc/pacman.d/hooks/90-mkinitcpio-install.hook` watches `extramodules/` and `firmware/`).
- DRM card numbers can change with load order; `egpu-drm-devices` resolves cards by PCI vendor, so
  the Hyprland side is unaffected.
- The Arch Wiki warns that early-loading nvidia breaks hibernation; this machine has zram swap only
  and no `resume` hook, so it does not apply.

**Undo.**

```sh
sudo cp ~/boot-backup-2026-10-17-0120/snapshots.conf /etc/mkinitcpio.conf.d/snapshots.conf
sudo rm /etc/mkinitcpio.conf.d/gpu.conf
sudo limine-mkinitcpio
```

If a boot fails outright, the Limine Snapshots entries made before this change boot the old UKI kept
in `/boot/<machine-id>/limine_history` until they rotate out, and the backup UKI is there for a
live-USB recovery.

References: Arch Wiki, NVIDIA (Early loading) and Plymouth (Using SimpleDRM).

## 2026-10-05: close the web ports

`sudo ufw delete allow 80/tcp` and `sudo ufw delete allow 443/tcp`, removing the rules added on
2026-08-05. Undo: `sudo ufw allow 80/tcp`, `sudo ufw allow 443/tcp`.

## 2026-09-03 and 2026-09-07: Docker and containerd data on the Repos drive

`/etc/docker/daemon.json` sets `data-root` to a `.docker-data` directory on the external Repos drive,
and `/etc/containerd/config.toml` (`version = 2`) points containerd's `root` at a `containerd`
directory inside it, so images and containers stay off the internal SSD. The first `config.toml`,
written at 13:29 on 2026-09-07, did not parse ("Failure unmarshaling TOML"), and containerd kept
failing until the file was rewritten and the daemons restarted at 14:40. Neither daemon is enabled at
boot; Docker is started by hand when needed, and needs the Repos drive mounted. Undo: delete both
files and restart both daemons (`sudo systemctl restart containerd docker`); they then use the
default `/var/lib/docker` and `/var/lib/containerd` again, and the images on the Repos drive are not
carried over.

## 2026-08-24: Cloudflare DNS

`make dns` installed `etc/NetworkManager/conf.d/20-dns.conf` from this repo and reloaded
NetworkManager. The file is tracked; see `CLAUDE.md` for how to verify it.

## 2026-08-05: printing and scanning

- `sudo systemctl enable --now avahi-daemon.service` enabled and started Avahi. It had not been
  enabled, so when simple-scan started at 15:36 its D-Bus activation request for Avahi failed (the
  `dbus-org.freedesktop.Avahi.service` alias exists only once the unit is enabled). `systemctl enable --now` was also run on `cups.socket` and
  `cups.service`, but CUPS had been enabled and running since the install, so that changed nothing.
- The `epson-inkjet-printer-escpr` driver was installed, and an Epson WF-3640 queue was added with
  system-config-printer and set as the default printer. The journal shows its cups-pk-helper
  mechanism starting at 15:45:40, the same second the queue's PPD was written and CUPS logged
  `CUPS-Add-Modify-Printer` and `CUPS-Set-Default`. `sane-airscan` was installed for the scanner.
- The firewall gained `5353/udp` (mDNS; presumably for discovering the printer and its scanner, since
  it was added during that setup, 26 s after avahi-daemon started), plus `80/tcp` and `443/tcp`,
  which were removed again on 2026-10-05.

## 2026-07-26 to 2026-07-29: firewall

`ufw.service` had been enabled at install, but `ufw.conf` said `ENABLED=no`, so no rules loaded. On
2026-07-26: `sudo ufw enable`, `sudo ufw allow 5520/udp` (Hytale: the launcher had just been
installed, and `ufw allow Hytale` was tried first), then `sudo ufw disable` the same evening. On
2026-07-29 `sudo ufw enable` again, which left `ENABLED=yes` in `/etc/ufw/ufw.conf`. Defaults are
drop inbound, allow outbound. Current inbound allows, IPv4 and IPv6: `5520/udp` and `5353/udp`. Undo:
`sudo ufw disable`.

## 2026-07-13: Repos drive and Docker

- A USB SSD (`/dev/sda` at the time) was partitioned GPT with one partition, formatted
  `mkfs.btrfs -L Repos`, given `btrfs property set ... compression zstd` and chowned to `michael`.
  It is not in `fstab`; udisks mounts it at `/run/media/michael/Repos`.
- Docker and containerd installed; `michael` added to the `docker` group (`usermod -aG docker`).
- `~/boot-backup-2026-06-23-2010/`, the backups from the snapper setup, deleted.

## 2026-07-03: NVIDIA eGPU

nvidia-open and nvidia-utils installed for the RTX 3080 Ti. `/etc/modprobe.d/nvidia-power.conf` sets
`options nvidia NVreg_PreserveVideoMemoryAllocations=1`, which per NVIDIA's documentation preserves
video memory across suspend, and `nvidia-suspend`, `nvidia-hibernate` and `nvidia-resume` were
enabled to go with it. `michael` was added to the `gamemode` group. Undo: remove the file, disable
the three services.

## 2026-06-30: kernel preset removed

During the linux 7.0.12 to 7.0.14 upgrade, mkinitcpio's `60-mkinitcpio-remove.hook` moved the edited
`/etc/mkinitcpio.d/linux.preset` to `linux.preset.pacsave`, and it was never recreated:
limine-mkinitcpio builds the initramfs and UKI without a preset.

## 2026-06-23: snapshots, seamless login, splash, radios

**Seamless login and splash** (around 01:45 to 01:55). Applied by `~/setup/seamless-login.sh`.

- `/etc/systemd/system/getty@tty1.service.d/autologin.conf`: agetty `--autologin michael` on tty1;
  tty2 to tty6 still prompt, for recovery. `~/.zprofile` then starts uwsm and Hyprland.
- A mistyped first attempt (`sudo mkdir -p /etc/systemd/systemm/getty@tty1.service.d`) left an empty
  `/etc/systemd/systemm/` tree. It is harmless; undo with `sudo rm -r /etc/systemd/systemm`.
- Login shell changed to zsh, presumably by the script's `chsh -s /usr/bin/zsh` (chsh needs no sudo,
  so no log records it; the shell is `/usr/bin/zsh` today).
- `plymouth` added to `HOOKS` in `/etc/mkinitcpio.conf` (later superseded by `snapshots.conf`).
- `quiet splash` appended to `/etc/kernel/cmdline` and to the old `/boot/limine/limine.conf`, which
  also gained a verbose fallback entry before it was demoted. That entry pointed at
  `arch-linux-fallback.efi`, which the install's preset never built.
- The `arch-matte` theme copied to `/usr/share/plymouth/themes/` and set with
  `plymouth-set-default-theme -R arch-matte`, which writes `Theme=arch-matte` to `plymouthd.conf` and
  rebuilt `/boot/EFI/Linux/arch-linux.efi` (created 01:53:40, nine seconds later, with `quiet splash`
  in its embedded command line).

**Wi-Fi and Bluetooth** (around 02:06). Applied by `~/setup/fix-net-bt.sh` and
`~/setup/remove-iwd.sh`.

- NetworkManager's backend switched from iwd (archinstall's choice) to wpa_supplicant in
  `/etc/NetworkManager/conf.d/wifi_backend.conf`; `iwd.service` stopped and left disabled
  (archinstall had disabled it, but NetworkManager started it), iwd removed, and `/var/lib/iwd` and
  `/etc/iwd` deleted.
- `AutoEnable=false` in `/etc/bluetooth/main.conf`, meant to keep Bluetooth off after a reboot once
  it was turned off (the script's stated aim). Since 2026-08-24 the bar's `bluetooth-power` keeps the
  radio off with the rfkill soft block instead, which systemd-rfkill restores at boot.

**Theming** (around 02:57). `sudo papirus-folders -C orange -t Papirus-Dark` (from
`~/setup/theming.sh`) recoloured the Papirus folder icons under `/usr/share/icons`.

**NVRAM cleanup** (20:07). `sudo efibootmgr -b 0004 -B` deleted Boot0004, which that day's setup
notes record as a dangling `Windows Boot Manager` entry pointing at a disk GUID no longer present (no
system log keeps the entry itself). This machine is single-OS.

**Bootable snapshots, Limine + snapper** (20:10 to 20:32). Applied by
`~/setup/snapper-limine-setup.sh`, then `~/setup/snapper-limine-resume.sh` after it stopped on the
existing `/.snapshots` subvolume.

- Installed limine-mkinitcpio-hook, limine-snapper-sync, snap-pac and inotify-tools.
- `/etc/mkinitcpio.d/linux.preset` rewritten from UKI output to a plain initramfs (limine-entry-tool
  assembles the UKI itself). The preset was removed on 2026-06-30.
- `/etc/mkinitcpio.conf.d/snapshots.conf` created with the full `HOOKS` line plus `btrfs-overlayfs`.
- `/etc/default/limine` written: `ENABLE_UKI=yes`, `CUSTOM_UKI_NAME="arch"`,
  `ENABLE_LIMINE_FALLBACK=yes`, `FIND_BOOTLOADERS=yes`, `BOOT_ORDER="*, *fallback, Snapshots"`,
  `MAX_SNAPSHOT_ENTRIES=5`, `SNAPSHOT_FORMAT_CHOICE=5`, `LIMIT_USAGE_PERCENT=80`,
  `RESTORE_METHOD="replace"` and the kernel command line.
- snapper (set up by archinstall): the `home` config deleted; `/etc/snapper/configs/root` restored
  from the pre-existing config and tuned to `TIMELINE_CREATE="no"`, `NUMBER_LIMIT="5"`,
  `NUMBER_LIMIT_IMPORTANT="5"`; `SNAPPER_CONFIGS="root"` in `/etc/conf.d/snapper`; btrfs quotas
  disabled on `/`.
- Services: `limine-snapper-sync.service` enabled; `snapper-cleanup.timer` (enabled by archinstall)
  restarted; `snapper-timeline.timer` disabled by hand afterwards
  (`sudo systemctl disable --now snapper-timeline.timer`, 20:32).
- ESP: the install's `/boot/limine/limine.conf` (written by archinstall, inferred: no logged command
  created it), edited earlier that day by seamless-login.sh, renamed to `limine.conf.disabled`,
  because it outranked the managed `/boot/limine.conf` in Limine's search order. It and
  `/boot/EFI/Linux/arch-linux.efi` remain, but that UKI's kernel 7.0.12 no longer matches
  `/usr/lib/modules`, so it is not a working recovery path.
- NVRAM: the package's `80-limine-efi-deploy.hook` ran `limine-install` during the install of
  limine-mkinitcpio-hook (20:13, so not in the sudo log), which created the `Limine` entry for
  `\EFI\limine\limine_x64.efi`; it is the current boot entry.

**Sensors** (21:03). `iio-sensor-proxy` installed for ambient-light auto-brightness.
`sudo systemctl enable --now iio-sensor-proxy` was run twice, but the unit is static (no `[Install]`
section) and is started by its udev rule (`80-iio-sensor-proxy.rules`), so there is nothing to
enable: the journal shows it starting at install and again after each attempt.

## 2026-06-22: install

The system was installed with archinstall (`/var/log/archinstall/install.log`; the first
`pacman.log` entries are its `pacman ... -r /mnt` runs). The log shows a first pass at 17:21 with
systemd-boot and the final one at 18:04 with Limine, completed at 18:07. The final pass set up LUKS
on `nvme0n1p2`, btrfs subvolumes `@`, `@home`, `@cache`, `@pkg` and `@log` mounted with
`compress=zstd:3`, a 1G vfat ESP at `/boot`, zram swap (`zram-generator.conf`, zstd), the
`en_US.UTF-8` locale, a US X11 keymap, Limine with a UKI and `99-limine.hook`, an mkinitcpio
`HOOKS` line using `udev`, `keymap`, `consolefont` and `encrypt`, and `pacman.conf` with `Color`
and `[multilib]`. It enabled NetworkManager (iwd backend, `iwd.service` disabled),
`bluetooth.service`, `cups.service` (with `cups.socket` and `cups.path`), `ufw.service`,
`power-profiles-daemon` and `systemd-timesyncd`, and set up snapper with `snapper-timeline.timer`
and `snapper-cleanup.timer` enabled.

The same evening `ILoveCandy` was added to `pacman.conf` by hand (`sed`, 21:26). `sudo systemctl
enable --now bluetooth` was also run, a no-op: archinstall had enabled `bluetooth.service` and it
had been running since first boot.

The ESP is mounted `fmask=0022`, so `/boot/loader/random-seed` is world-readable and systemd warns
about it at every boot.

## Firmware

- BIOS 03.04 (dated 2025-11-06).
- Secure Boot is off (the `SecureBoot` EFI variable reads 0).
- The battery charge limit is 80%, set in the BIOS according to the June setup notes. The system
  shows only the effect: charging stops at 80%, and no sysfs charge threshold is exposed
  (`cros_charge-control` would need `probe_with_fwk_charge_control=1`).
