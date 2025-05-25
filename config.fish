set fish_greeting 


export STARSHIP_CONFIG=/home/funinkina/dotfiles/starship.toml
set FZF_DEFAULT_OPTS "--layout=reverse --exact --border=bold --border=rounded --margin=3% --color=dark"

function fish_user_key_bindings
  fish_default_key_bindings
  # fish_vi_key_bindings
end

function fish_command_not_found
    set -l cmd $argv[1]
    set -l results (pkgfile -b $cmd)

    if test -n "$results"
        echo -e "\e[1;31mCommand '$cmd' not found.\e[0m It is available in the following package(s):"

        for i in (seq (count $results))
            echo -e "$i. \e[1;36m$results[$i]\e[0m"
        end

        read -P "Enter the number of the package to install, or 0 to cancel: " choice

        if test "$choice" -gt 0 -a "$choice" -le (count $results)
            set -l selected_pkg $results[$choice]
            echo -e "Installing \e[1;32m$selected_pkg\e[0m..."
            yay -S $selected_pkg
        else if test "$choice" -eq 0
            echo "Installation cancelled."
        else
            echo "Invalid selection."
        end
    else
        echo -e "\e[1;31mCommand '$cmd' not found and no matching package was found.\e[0m"
    end
end



# Functions needed for !! and !$
function __history_previous_command
  switch (commandline -t)
  case "!"
    commandline -t $history[1]; commandline -f repaint
  case "*"
    commandline -i !
  end
end

function __history_previous_command_arguments
  switch (commandline -t)
  case "!"
    commandline -t ""
    commandline -f history-token-search-backward
  case "*"
    commandline -i '$'
  end
end

# The bindings for !! and !$
if [ "$fish_key_bindings" = "fish_vi_key_bindings" ];
  bind -Minsert ! __history_previous_command
  bind -Minsert '$' __history_previous_command_arguments
else
  bind ! __history_previous_command
  bind '$' __history_previous_command_arguments
end


# Aliases
alias yeet="sudo pacman -Rcnus"
alias update="sudo pacman -Syyu && sudo pkgfile --update"
alias get="yay -S"
alias search="pacman -Ss"
alias list="pacman -Q | grep"
alias pacinfo="pacman -Qi"
alias edit="sudo vim"
alias sse="sudo systemctl enable"
alias ssd="sudo systemctl disable"
alias sstart="sudo systemctl start"
alias sstop="sudo systemctl stop"
alias c="clear"
alias e="exit"
alias s="sudo"
#navigation
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'
# listing
alias ls='eza -al --color=always --group-directories-first' # preferred listing
alias la='eza -a --color=always --group-directories-first'  # all files and dirs
alias ll='eza -l --color=always --group-directories-first'  # long format
alias lt='eza -aT --color=always --group-directories-first' # tree listing
alias l.='eza -a | egrep "^\."'
alias l.='eza -al --color=always --group-directories-first ../' # ls on the PARENT directory
alias l..='eza -al --color=always --group-directories-first ../../' # ls on directory 2 levels up
alias l...='eza -al --color=always --group-directories-first ../../../' # ls on directory 3 levels up

alias python="python3"

#git
alias addup='git add -u'
alias addall='git add .'
alias branch='git branch'
alias checkout='git checkout'
alias clone='git clone'
alias commit='git commit -m'
alias fetch='git fetch'
alias pull='git pull origin'
alias push='git push origin'
alias tag='git tag'
alias newtag='git tag -a'


# FZF bindings
fzf_key_bindings

starship init fish | source
