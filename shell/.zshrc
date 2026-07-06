# ~/.zshrc

# ── History ──────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt INC_APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE EXTENDED_HISTORY

# ── Behaviour ────────────────────────────────────────────────────────
setopt AUTO_CD INTERACTIVE_COMMENTS
bindkey -e   # emacs keybindings

# ── Completion ───────────────────────────────────────────────────────
fpath+=(/usr/share/zsh/site-functions)
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# ── Prompt (matte-black accent) ──────────────────────────────────────
autoload -Uz colors && colors
setopt PROMPT_SUBST
PROMPT='%F{246}%n@%m%f %F{214}%~%f %F{246}❯%f '

# ── Aliases ──────────────────────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'

# Add ~/.local/bin to PATH (web2app, wifi-connect, etc.)
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

# ── NVM (Node Version Manager) ───────────────────────────────────────
# AUR 'nvm' pkg lives in /usr/share/nvm. Source nvm.sh directly, NOT
# init-nvm.sh, whose bash_completion errors under zsh (compdef: _comps).
export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
[ -d "$NVM_DIR" ] || mkdir -p "$NVM_DIR"
[ -e "$NVM_DIR/nvm.sh" ]   || ln -s /usr/share/nvm/nvm.sh   "$NVM_DIR/nvm.sh"
[ -e "$NVM_DIR/nvm-exec" ] || ln -s /usr/share/nvm/nvm-exec "$NVM_DIR/nvm-exec"
[ -s /usr/share/nvm/nvm.sh ] && source /usr/share/nvm/nvm.sh
