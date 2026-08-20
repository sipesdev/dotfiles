# GNU Stow dotfiles. `make` (or `make stow`) symlinks every package into $HOME.
STOW := stow --no-folding --verbose --target=$(HOME)
PKGS := hypr quickshell localbin webapps shell gtk qt uwsm alacritty gamemode mangohud dxvk

.PHONY: all stow restow unstow list
all: stow
stow:   ; $(STOW) $(PKGS)
restow: ; $(STOW) --restow $(PKGS)   # prune orphaned symlinks after renames
unstow: ; $(STOW) --delete $(PKGS)
list:   ; @echo $(PKGS)
