# Command shortcuts
alias rm="rm -i"
alias ll="ls -ltA"
alias vi="vim"

# File shortcuts
alias bashrc="vim ~/.bashrc && source ~/.bashrc"
alias vimrc="vim ~/.vimrc"

# Bash completion
if [ -f $(brew --prefix)/etc/bash_completion ]; then
  . $(brew --prefix)/etc/bash_completion
fi

# Git branch on prompt
export PS1="jerry@\h:\[\e[1;33m\]\w\[\e[m\]\[\e[1;32m\]\$(__git_ps1 ' [%s] ')\[\e[m\]\$ "

# Colored files
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced
