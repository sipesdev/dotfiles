# GNU Stow dotfiles. `make` (or `make stow`) symlinks every package into $HOME.
STOW := stow --no-folding --verbose --target=$(HOME)
PKGS := hypr quickshell localbin webapps shell gtk qt uwsm alacritty gamemode mangohud dxvk

.PHONY: all stow restow unstow list
all: stow
stow:   ; $(STOW) $(PKGS)
restow: ; $(STOW) --restow $(PKGS)   # prune orphaned symlinks after renames
unstow: ; $(STOW) --delete $(PKGS)
list:   ; @echo $(PKGS)

# ── System (root) config that stow cannot deliver ────────────────
# Global DNS override for NetworkManager (Cloudflare). Not a stow package: needs root.
DNS_CONF := etc/NetworkManager/conf.d/20-dns.conf
.PHONY: dns
dns:
	sudo install -Dm644 $(DNS_CONF) /$(DNS_CONF)
	sudo nmcli general reload conf
	sudo nmcli general reload dns-full
	@grep nameserver /etc/resolv.conf
