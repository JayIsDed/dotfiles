# ─── ZSH Config ─────────────────────────────────────
# github.com/JayIsDed/dotfiles

# ─── History ────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS

# ─── Directory Navigation ──────────────────────────
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS

# ─── Completion ────────────────────────────────────
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ─── Key Bindings ──────────────────────────────────
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# ─── Aliases ───────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ..='cd ..'
alias ...='cd ../..'

# Git
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline -15'
alias gd='git diff'

# SSH hosts
alias dev='ssh claude-dev'
alias docker='ssh docker-services'

# System
alias update='sudo pacman -Syu'
alias cleanup='sudo pacman -Rns $(pacman -Qdtq) 2>/dev/null || echo "nothing to clean"'
alias reload='hyprctl reload'

# ─── Environment ───────────────────────────────────
export EDITOR=nano
export VISUAL=nano
export BROWSER=firefox
export TERM=xterm-256color

# ─── Starship Prompt ──────────────────────────────
eval "$(starship init zsh)"

# ─── Fastfetch on new terminal ────────────────────
if [[ -o interactive ]] && [[ -z "$TMUX" ]] && [[ -z "$VSCODE_PID" ]]; then
    fastfetch
fi
