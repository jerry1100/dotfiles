# Command shortcuts
alias rm="rm -i"
alias ll="ls -ltA"

# File shortcuts
alias bashrc="vi ~/.bashrc && source ~/.bashrc"
alias vimrc="vi ~/.vimrc"

# Bash completion
if [ -f $(brew --prefix)/etc/bash_completion ]; then
  . $(brew --prefix)/etc/bash_completion
fi

# Git branch on prompt
export PS1="jerry@\h:\[\e[1;33m\]\w\[\e[m\]\[\e[1;32m\]\$(__git_ps1 ' [%s] ')\[\e[m\]\$ "

# Colored files
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced
