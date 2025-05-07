ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

export PATH=$PATH:/home/funinkina/.local/bin
export LANG=en_IN.UTF-8
export LC_ALL=en_IN.UTF-8
export STARSHIP_CONFIG=~/dotfiles/starship.toml

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
alias search="pacman -Ss"
alias list="pacman -Q | grep"
alias info="pacman -Qi"
alias edit="sudo vim"
alias sse="sudo systemctl enable"
alias ssd="sudo systemctl disable"
alias sstart="sudo systemctl start"
alias sstop="sudo systemctl stop"
alias c="clear"
alias e="exit"
alias s="sudo-rs"
alias sudo="sudo-rs"
alias ..="cd .."
alias ...="cd ../.."
alias ~="cd ~"
alias ll="ls -alF"
alias la="ls -A"
alias l="ls -CF"
alias gc="git clone"
alias cdir='cd "${_%/*}"'
alias python="python3"
alias cat="bat"

echo ""
echo "🕒 It's $(date '+%A, %B %d at %H:%M')"
echo "⏳ System has been up for $(uptime -p | sed 's/up //')."
source <(fzf --zsh)

eval "$(starship init zsh)"
