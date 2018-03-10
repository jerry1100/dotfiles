# Command shortcuts
alias rm="rm -i"
alias ll="ls -ltA"
alias lll="ll | less"
alias vi="vim"
alias grep="grep --color=auto"

# File shortcuts
alias bashrc="vim ~/.bashrc && source ~/.bashrc"
alias vimrc="vim ~/.vimrc"
alias gitconfig="vim ~/github/dotfiles/gitconfig"

# Bash completion
if [ -f $(brew --prefix)/etc/bash_completion ]; then
    . $(brew --prefix)/etc/bash_completion
fi

# Git branch on prompt
export PS1="jerry@\h:\[\e[1;33m\]\w\[\e[m\]\[\e[1;32m\]\$(__git_ps1 ' [%s] ')\[\e[m\]\$ "
export GIT_PS1_DESCRIBE_STYLE=branch # show refs in detached state
export GIT_PS1_SHOWDIRTYSTATE=true # show '*' if uncomitted changes
export GIT_PS1_SHOWSTASHSTATE=true # show '$' if stash is not empty
export GIT_PS1_SHOWUNTRACKEDFILES=true # show '%' if untracked files

# Colored files
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced

# Add home /bin to path
if [[ $PATH != *${HOME}/bin* ]]; then
    export PATH="$PATH:${HOME}/bin"
fi
