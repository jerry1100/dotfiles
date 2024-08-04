# Color files and folders
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced

# zstyle list-colors only works with LS_COLORS, which is the linux version of
# mac's LSCOLORS. Converted using: https://geoff.greer.fm/lscolors/
export LS_COLORS="di=1;36:ln=1;35:so=1;32:pi=1;33:ex=1;31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=34;43"

# Options
setopt nobeep # don't beep
setopt noautomenu # don't auto insert after second tab

# Aliases
alias rm="rm -i"
alias ll="ls -lthA"
alias lll="ll | less"
alias grep="grep --color=auto"

# Add home bin to path
export PATH="$HOME/bin:$PATH"

# Tab completion
autoload -U compinit && compinit

# Color partial tab completions, also color file completions
# Adapted from https://stackoverflow.com/questions/8300687/zsh-color-partial-tab-completions
zstyle -e ':completion:*:default' list-colors 'reply=("${PREFIX:+=(#bi)($PREFIX:t)(?)*==91}:${(s.:.)LS_COLORS}")'

# Enable case insensitive autocomplete
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*'

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
    user="%n"
    dir="%F{yellow}%~%f"
    branch="%F{green}$(__git_ps1 '[%s] ' | sed "s/HEAD/master/" | sed 's/remotes\///')%f"
    PROMPT="${user} ${dir} ${branch}%# "
}

# Push branch and open a PR
function pr() {
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  REPO="$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')"

  echo "Pushing $BRANCH to $REPO..."
  git push -u origin "$BRANCH"

  open "https://github.com/$REPO/compare/$BRANCH"
}
