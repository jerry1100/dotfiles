# Color files and folders
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced

# Options
setopt nolistbeep # don't beep when listing completions
setopt noautomenu # don't auto insert after second tab

# Aliases
alias rm="rm -i"
alias ll="ls -lthA"
alias lll="ll | less"
alias grep="grep --color=auto"

# Vim master race
export EDITOR="vim"

# Add home bin to path
export PATH="$HOME/bin:$PATH"

# Git prompt
export GIT_PS1_DESCRIBE_STYLE=branch # show refs in detached state
export GIT_PS1_SHOWDIRTYSTATE=true # show '*' if uncomitted changes
export GIT_PS1_SHOWSTASHSTATE=true # show '$' if stash is not empty
export GIT_PS1_SHOWUNTRACKEDFILES=true # show '%' if untracked files

# Note: tried using zsh's vcs_info but configuration was messy and took too
# much effort to support showing untracked files state. Download from:
# https://github.com/git/git/blob/master/contrib/completion/git-prompt.sh
source ~/bin/git-prompt.sh

# Build prompt
precmd() {
    user="%n@%m"
    dir="%F{yellow}%~%f"
    branch="%F{green}$(__git_ps1 ' [%s]')%f"
    PROMPT="${user}:${dir}${branch} %# "
}
