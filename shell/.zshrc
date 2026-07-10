# ~/.zshrc

# ── History ──────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt INC_APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE EXTENDED_HISTORY
setopt HIST_FIND_NO_DUPS HIST_SAVE_NO_DUPS HIST_REDUCE_BLANKS

# ── Behaviour ────────────────────────────────────────────────────────
setopt AUTO_CD INTERACTIVE_COMMENTS
setopt AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT   # cd keeps a dir stack; `cd -<Tab>` jumps back
setopt COMPLETE_IN_WORD                            # complete from the cursor, not just line end
unsetopt BEEP                                      # no terminal bell
bindkey -e                                         # emacs keybindings

# Treat path separators as word boundaries so Ctrl+Left/Right and Ctrl+W
# stop at each /dir/ component instead of jumping the whole path.
WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'

# ── Completion ───────────────────────────────────────────────────────
fpath+=(/usr/share/zsh/site-functions)
autoload -Uz compinit && compinit
[[ -z $LS_COLORS ]] && eval "$(dircolors -b 2>/dev/null)"   # populate colours for ls + menu
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # case-insensitive
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}       # colourise the match list
zstyle ':completion:*:descriptions' format '%F{214}%d%f'    # orange group headers

# ── Key bindings ─────────────────────────────────────────────────────
# xterm/DEC sequences, matching Alacritty (TERM=xterm-256color).
# Word jumping
bindkey '^[[1;5C' forward-word      # Ctrl+Right
bindkey '^[[1;5D' backward-word     # Ctrl+Left
bindkey '^[[1;3C' forward-word      # Alt+Right
bindkey '^[[1;3D' backward-word     # Alt+Left
# Line jumping (both normal and application cursor mode)
bindkey '^[[H'  beginning-of-line   # Home
bindkey '^[[F'  end-of-line         # End
bindkey '^[OH'  beginning-of-line   # Home  (app mode)
bindkey '^[OF'  end-of-line         # End   (app mode)
# Deletion
bindkey '^[[3~'   delete-char           # Delete
bindkey '^[[3;5~' kill-word             # Ctrl+Delete    -> delete word right
bindkey '^H'      backward-kill-word    # Ctrl+Backspace -> delete word left
bindkey '^[[Z'    reverse-menu-complete # Shift+Tab      -> cycle completions backwards

# ── Plugins (Arch official packages; sourced only if present) ─────────
# Install:  sudo pacman -S zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search
# Order matters: autosuggestions, then syntax-highlighting (must wrap last),
# then history-substring-search (must load after syntax-highlighting).
ZSH_PLUGINS=/usr/share/zsh/plugins

# fish-style greyed inline suggestion pulled from history; accept with Right arrow / End.
if [[ -r $ZSH_PLUGINS/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source $ZSH_PLUGINS/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#585858'   # dim grey, matches the matte-black theme
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# Live colouring of the command line: valid commands green, unknown red, paths underlined.
if [[ -r $ZSH_PLUGINS/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source $ZSH_PLUGINS/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Type a prefix, then Up/Down cycles only the history entries that match it.
if [[ -r $ZSH_PLUGINS/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
  source $ZSH_PLUGINS/zsh-history-substring-search/zsh-history-substring-search.zsh
  bindkey '^[[A' history-substring-search-up      # Up
  bindkey '^[[B' history-substring-search-down    # Down
  bindkey '^[OA' history-substring-search-up      # Up   (app mode)
  bindkey '^[OB' history-substring-search-down    # Down (app mode)
fi

# ── Prompt (matte-black accent) ──────────────────────────────────────
autoload -Uz colors && colors
setopt PROMPT_SUBST
PROMPT='%F{246}%n@%m%f %F{214}%~%f %F{246}❯%f '

# ── Aliases ──────────────────────────────────────────────────────────
alias ls='ls -alh --color=auto'          # long listing, all files, human sizes (K/M/G)
alias ll='command ls -lh --color=auto'   # long + human sizes, without hidden files
alias la='command ls -A  --color=auto'   # all files, columnar
alias grep='grep --color=auto'
alias ..='cd ..'
alias ff='fastfetch'

# Add ~/.local/bin to PATH (web2app, wifi-connect, etc.)
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

# ── SSH agent (Bitwarden) ────────────────────────────────────────────
# Bitwarden desktop is the SSH agent; private keys live in the vault,
# never on disk. Needs Bitwarden running + unlocked. Native (non-Flatpak)
# install exposes the socket at ~/.bitwarden-ssh-agent.sock.
export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"

# ── NVM (Node Version Manager) ───────────────────────────────────────
# AUR 'nvm' pkg lives in /usr/share/nvm. Source nvm.sh directly, NOT
# init-nvm.sh, whose bash_completion errors under zsh (compdef: _comps).
export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
[ -d "$NVM_DIR" ] || mkdir -p "$NVM_DIR"
[ -e "$NVM_DIR/nvm.sh" ]   || ln -s /usr/share/nvm/nvm.sh   "$NVM_DIR/nvm.sh"
[ -e "$NVM_DIR/nvm-exec" ] || ln -s /usr/share/nvm/nvm-exec "$NVM_DIR/nvm-exec"
[ -s /usr/share/nvm/nvm.sh ] && source /usr/share/nvm/nvm.sh
