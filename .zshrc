# ─── ZSH Config ─────────────────────────────────────
# github.com/JayIsDed/dotfiles

# ─── Oh My Zsh ────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"

plugins=(
    git
    sudo
    archlinux
    zsh-autosuggestions
    zsh-syntax-highlighting
    fast-syntax-highlighting
    copyfile
    copybuffer
    dirhistory
)

source $ZSH/oh-my-zsh.sh

# ─── History ────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt appendhistory

# ─── FZF ───────────────────────────────────────────
source <(fzf --zsh)

# ─── Key Bindings ──────────────────────────────────
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# ─── Aliases ───────────────────────────────────────
alias ls='eza -a --icons=always'
alias ll='eza -al --icons=always'
alias lt='eza -a --tree --level=1 --icons=always'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'
alias nf='fastfetch'

# Git
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline -15'
alias gd='git diff'

# SSH hosts
alias dev='ssh claude-dev'
alias dock='ssh docker-services'

# System
alias update='sudo pacman -Syu'
alias cleanup='sudo pacman -Rns $(pacman -Qdtq) 2>/dev/null || echo "nothing to clean"'
alias reload='hyprctl reload'

# ─── Environment ───────────────────────────────────
export EDITOR=nano
export VISUAL=nano
export BROWSER=firefox
export TERM=xterm-256color
export PATH=$PATH:~/.local/bin

# ─── Oh My Posh Prompt ───────────────────────────
eval "$(oh-my-posh init zsh --config $HOME/.config/ohmyposh/prompt.toml)"

# ─── Fastfetch on new terminal ────────────────────
if [[ -o interactive ]] && [[ -z "$TMUX" ]] && [[ -z "$VSCODE_PID" ]]; then
    fastfetch
fi
