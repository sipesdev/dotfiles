# GNU Stow dotfiles. `make` (or `make stow`) symlinks every package into $HOME.
STOW := stow --no-folding --verbose --target=$(HOME)
PKGS := hypr quickshell localbin webapps shell gtk qt uwsm alacritty gamemode mangohud dxvk agents systemd doom

.PHONY: all stow restow unstow list test
all: stow
stow:   ; $(STOW) $(PKGS)
restow: ; $(STOW) --restow $(PKGS)   # prune orphaned symlinks after renames
unstow: ; $(STOW) --delete $(PKGS)
list:   ; @echo $(PKGS)
test:   ; node --test tests/quickshell/*.test.js && PYTHONDONTWRITEBYTECODE=1 python tests/agents/test_collectors.py   # pure JS + collector models; no .pyc inside the stow package

# ── System (root) config that stow cannot deliver ────────────────
# Global DNS override for NetworkManager (Cloudflare). Not a stow package: needs root.
DNS_CONF := etc/NetworkManager/conf.d/20-dns.conf
.PHONY: dns
dns:
	sudo install -Dm644 $(DNS_CONF) /$(DNS_CONF)
	sudo nmcli general reload conf
	sudo nmcli general reload dns-full
	@grep nameserver /etc/resolv.conf

# ── Agent plumbing stow cannot deliver ───────────────────────────
# Claude Code reads skills from ~/.claude/skills (a skill dir may be a
# symlink); ~/.claude itself is not stowed. Idempotent.
.PHONY: agents-setup
agents-setup:
	mkdir -p $(HOME)/.claude/skills
	ln -sfn $(HOME)/.agents/skills/dotfiles $(HOME)/.claude/skills/dotfiles
	ln -sfn $(HOME)/.agents/skills/diagnose-crash $(HOME)/.claude/skills/diagnose-crash
	systemctl --user daemon-reload
	systemctl --user enable --now crash-watch.service
	systemctl --user is-active crash-watch.service
