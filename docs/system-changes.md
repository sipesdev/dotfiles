# System changes outside the stow packages

A record of changes to root-owned system files this repo does not track (`/etc`, the ESP).
Tracked root config lives in `etc/` and is applied by `make dns`; everything here was changed in
place, so this log is the only history. Add an entry for every such change, newest first: what
changed, why, how it was applied and verified, and how to undo it.

Older system changes (the Limine + snapper setup, the seamless login, the NVIDIA modprobe options)
predate this log and are not recorded yet.

## Untracked files touched so far

| File | Role | Changed |
|---|---|---|
| `/etc/mkinitcpio.conf.d/snapshots.conf` | The effective `HOOKS` line: drop-ins are sourced after `/etc/mkinitcpio.conf`, so the `HOOKS` there is dead. Adds `btrfs-overlayfs` so read-only snapshots boot writable. | Created 2026-06-23, edited 2026-10-17 |
| `/etc/mkinitcpio.conf.d/gpu.conf` | `MODULES` for early KMS on both GPUs | Created 2026-10-17 |

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
