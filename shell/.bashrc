#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias emacs="emacsclient -t -a ''"   # terminal Emacs on the daemon; \emacs runs the bare binary
PS1='[\u@\h \W]\$ '
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.config/emacs/bin:"*) ;; *) export PATH="$HOME/.config/emacs/bin:$PATH" ;; esac
