# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

export ZSH="$HOME/.oh-my-zsh"

# Detect Termux
IS_TERMUX=0
if [[ -n "$TERMUX_VERSION" ]] || [[ -d "/data/data/com.termux" ]]; then
    IS_TERMUX=1
fi

# Set PATH based on platform
if [[ $IS_TERMUX -eq 1 ]]; then
    # Termux - use PREFIX for binaries
    export PATH="$PREFIX/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
else
    export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.cargo/bin:$HOME/.volta/bin:$HOME/.bun/bin:$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:$HOME/.config:$HOME/.cargo/bin:/usr/local/lib/*:$PATH"
fi

# Set nvim as default editor for opencode and other tools
export EDITOR="nvim"
export VISUAL="nvim"

if [[ $- == *i* ]]; then
    # Commands to run in interactive sessions can go here
fi

export LS_COLORS="di=38;5;67:ow=48;5;60:ex=38;5;132:ln=38;5;144:*.tar=38;5;180:*.zip=38;5;180:*.jpg=38;5;175:*.png=38;5;175:*.mp3=38;5;175:*.wav=38;5;175:*.txt=38;5;223:*.sh=38;5;132"
if [[ "$(uname)" == "Darwin" ]]; then
else
fi

# Homebrew setup (skip on Termux)
if [[ $IS_TERMUX -eq 0 ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS - check for Apple Silicon vs Intel
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            # Apple Silicon (M1/M2/M3)
            BREW_BIN="/opt/homebrew/bin"
        elif [[ -f "/usr/local/bin/brew" ]]; then
            # Intel Mac
            BREW_BIN="/usr/local/bin"
        fi
    else
        # Linux
        BREW_BIN="/home/linuxbrew/.linuxbrew/bin"
    fi

    # Only eval brew shellenv if brew is installed
    if [[ -n "$BREW_BIN" && -f "$BREW_BIN/brew" ]]; then
        eval "$($BREW_BIN/brew shellenv)"
    fi
fi

# Zsh plugins - different paths for Termux vs Homebrew
if [[ $IS_TERMUX -eq 1 ]]; then
    # Termux - plugins installed via pkg
    [[ -f "$PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ]] && source "$PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
    [[ -f "$PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    [[ -f "$PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    # Powerlevel10k on Termux - may need manual install
    [[ -f "$PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme" ]] && source "$PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme"
else
    # Safe sourcing for Homebrew Zsh plugins to prevent crashes if missing
    local BREW_SHARE="$(dirname $BREW_BIN)/share"
    [[ -f "$BREW_SHARE/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ]] && source "$BREW_SHARE/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
    [[ -f "$BREW_SHARE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$BREW_SHARE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    [[ -f "$BREW_SHARE/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$BREW_SHARE/zsh-autosuggestions/zsh-autosuggestions.zsh"
    [[ -f "$BREW_SHARE/powerlevel10k/powerlevel10k.zsh-theme" ]] && source "$BREW_SHARE/powerlevel10k/powerlevel10k.zsh-theme"
fi

export PROJECT_PATHS="$HOME/work"
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_DEFAULT_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exlude .git"

WM_VAR="/$TMUX"
# change with ZELLIJ
WM_CMD="tmux"
# change with zellij

function start_if_needed() {
    if [[ $- == *i* ]] && [[ -z "${WM_VAR#/}" ]] && [[ -t 1 ]]; then
        exec $WM_CMD
    fi
}
plugins=(
  command-not-found
)

source $ZSH/oh-my-zsh.sh

export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
# source <(carapace _carapace)

eval "$(fzf --zsh)"
eval "$(zoxide init zsh)"
eval "$(atuin init zsh)"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Remove duplicates from PATH
typeset -U path

# C++ Competitive Programming compiler
# Usage: cpp solution.cpp
function cpprun() {
  if [ -z "$1" ]; then
    echo "Usage: cpp <file.cpp>"
    return 1
  fi
  
  echo "🔨 Compilando $1 con C++23..."
  g++ -std=c++23 -O2 -Wall -Wextra -Wshadow -Wconversion \
      -D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC \
      -fsanitize=address -fsanitize=undefined \
      -o "${1%.*}" "$1"
  
  if [ $? -eq 0 ]; then
    echo "✅ Compilación exitosa. Ejecutando..."
    "./${1%.*}"
  else
    echo "❌ Error de compilación. Revisar errores arriba."
    return 1
  fi
}
alias cpp='cpprun'

if command -v tmux &> /dev/null; then
    start_if_needed
fi

# alias
alias fzfbat='fzf --preview="bat --theme=gruvbox-dark --color=always {}"'
alias fzfnvim='nvim $(fzf --preview="bat --theme=gruvbox-dark --color=always {}")'

# Modern CLI replacements
alias cat='bat'
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias la='eza -la --icons --group-directories-first'
alias tree='eza --tree --icons'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'

# Shortcuts útiles
alias vim='nvim'
alias v='nvim'
alias lg='lazygit'
alias ld='lazydocker'
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'

# Tmux shortcuts
alias ta='tmux attach'
alias tl='tmux list-sessions'
alias tn='tmux new -s'

#plugins

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
