ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

export PATH=$PATH:/home/funinkina/.local/bin
export LANG=en_IN.UTF-8
export LC_ALL=en_IN.UTF-8

zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
fpath+=~/.zfunc

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
HISTIGNORE="ls*:pwd*:c:clear"
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
alias yeet="sudo pacman -Rcnus"
alias update="yay"
alias get="yay -S"
alias search="search_package"
alias list="pacman -Q | grep"
alias info="pacman -Qi"
alias edit="sudo vim"
alias sse="sudo systemctl enable"
alias ssd="sudo systemctl disable"
alias sstart="sudo systemctl start"
alias sstop="sudo systemctl stop"
alias c="clear"
alias e="exit"
alias s="sudo"
alias ..="cd .."
alias ...="cd ../.."
alias ~="cd ~"
alias ll="ls -alF"  # Detailed listing with file types
alias la="ls -A"  # List all except . and ..
alias l="ls -CF"  # List only directories
alias gc="git clone"
alias cdir='cd "${_%/*}"'
alias python="python3"

search_package() {
    echo "\e[38;2;94;255;190m\e[1m$1 in official repositories:\e[m"
    pacman -Ss "$1"
    echo "\n\e[38;2;94;255;190m\e[1m$1 in AUR:\e[m"
    yay -Ss "$1"
}
eval "$(starship init zsh)"

[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
