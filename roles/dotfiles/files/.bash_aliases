# dotfiles
alias ddu='curl -fsSL https://raw.githubusercontent.com/PrzemyslawSagalo/dev_stack/main/bootstrap.sh | bash'

# Git
alias gs='git status'
alias gcb='git branch --show-current'
alias gpcb='git push origin $(gcb)'
alias gacw='git commit -am wip'
alias gdcb='git pull origin $(gcb)' # git download (pull) current branch
alias gl='git log'
alias geb='export cb=$(gcb)'

# Tmux
alias tnwc='tmux new-window -c $(pwd)'

# Python
alias pae='source venv/bin/activate'
alias pce='python -m venv venv && pae && pip install python-toolbox-przemek'
alias putb='pip install "python-toolbox-przemek[lint,tests]"'
## Tests
alias ptcr='coverage report -m'

# Shell
alias se='set -a && source .env && set +a'

# NeoVim
alias nv='nvim .'

# GitHub Copilot
copilot() {
    command copilot \
        --allow-tool="shell(ls)" \
        --allow-tool="shell(grep)" \
        --allow-tool="shell(cat)" \
        --allow-tool="shell(find)" \
        --allow-tool="shell(git:status)" \
        "$@"
}

alias cop='copilot'

# Google Anty Gravity
alias agyyolo='agy --dangerously-skip-permissions'
