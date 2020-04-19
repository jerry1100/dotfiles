export PROMPT="%n@%m:%F{yellow}%~%f %# "

# TODO Git branch on prompt
#export GIT_PS1_DESCRIBE_STYLE=branch # show refs in detached state
#export GIT_PS1_SHOWDIRTYSTATE=true # show '*' if uncomitted changes
#export GIT_PS1_SHOWSTASHSTATE=true # show '$' if stash is not empty
#export GIT_PS1_SHOWUNTRACKEDFILES=true # show '%' if untracked files

# Color files and folders
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced

# Vim master race
export EDITOR="vim"

# Add home bin to path
export PATH="$PATH:$HOME/bin"

# Options
setopt nolistbeep # don't beep when listing completions
setopt noautomenu # don't auto insert after second tab

# Aliases
alias rm="rm -i"
alias ll="ls -lthA"
alias lll="ll | less"
alias grep="grep --color=auto"
