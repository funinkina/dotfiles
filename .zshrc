ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

export PATH=$PATH:/home/funinkina/.local/bin

zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions

autoload -U compinit && compinit

bindkey '^f' autosuggest-accept
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey  "^[[H"   beginning-of-line
bindkey  "^[[F"   end-of-line
bindkey  "^[[3~"  delete-char

HISTSIZE=2000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_dups
setopt hist_ignore_all_dups
setopt hist_find_no_dups

#completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias ll='ls -alF'
    alias la='ls -A'
    alias l='ls -CF'
fi

#aliases
alias yeet="sudo pacman -Rns"
alias update="sudo pacman -Syyu"
alias install="install_package"
alias search="search_package"
alias list="pacman -Q | grep"
alias edit="sudo nano"
alias c="clear"
alias e="exit"
alias s="sudo"

install_package() {
    if ! sudo pacman -S "$1"; then
        echo "\e[38;2;94;255;190m\e[1mPackage not found in official repositories. Trying to install from AUR...\e[m\n"
        yay -S "$1"
    fi
}

search_package() {
    echo "\e[38;2;94;255;190m\e[1m$1 in official repositories:\e[m"
    pacman -Ss "$1"
    echo "\n\e[38;2;94;255;190m\e[1m$1 in AUR:\e[m"
    yay -Ss "$1"
}

eval "$(starship init zsh)"
