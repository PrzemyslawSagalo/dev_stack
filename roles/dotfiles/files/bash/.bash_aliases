# shellcheck shell=bash
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
alias lg='lazygit'

gsquash() {
    if [ "$#" -eq 1 ] && { [ "$1" = "-h" ] || [ "$1" = "--help" ]; }; then
        echo "Usage: gsquash [commit-hash]"
        echo "Collapse all commits after <commit-hash> (default: first commit on branch) into it, preserving its commit message."
        return 0
    fi

    if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ -z "$1" ]; }; then
        echo "Usage: gsquash [commit-hash]" >&2
        return 1
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: not inside a git work tree" >&2
        return 1
    fi

    if [ -n "$(git status --porcelain)" ]; then
        echo "Error: working tree is not clean; commit or stash changes first" >&2
        return 1
    fi

    local target=""
    if [ "$#" -eq 1 ]; then
        target="$(git rev-parse --verify "${1}^{commit}" 2>/dev/null)" || {
            echo "Error: invalid commit '$1'" >&2
            return 1
        }

        if ! git merge-base --is-ancestor "$target" HEAD 2>/dev/null; then
            echo "Error: commit '$1' is not an ancestor of HEAD" >&2
            return 1
        fi
    else
        local base_ref=""
        local candidate
        for candidate in origin/HEAD origin/main origin/master main master; do
            if git rev-parse --verify --quiet "${candidate}^{commit}" >/dev/null; then
                base_ref="$candidate"
                break
            fi
        done

        if [ -z "$base_ref" ]; then
            echo "Error: could not determine base branch (main/master); specify <commit-hash> explicitly" >&2
            return 1
        fi

        target="$(git rev-list --reverse "${base_ref}..HEAD" 2>/dev/null | head -n 1)"
        if [ -z "$target" ]; then
            echo "Error: no commits on current branch ahead of '$base_ref'" >&2
            return 1
        fi
    fi

    if [ "$(git rev-list --merges --count "${target}..HEAD")" -gt 0 ]; then
        echo "Error: merge commits exist between '${1:-$target}' and HEAD; rebase onto main first" >&2
        return 1
    fi

    if [ "$target" = "$(git rev-parse HEAD)" ]; then
        echo "Nothing to squash: HEAD is already at target commit"
        return 0
    fi

    git reset --soft "$target" && git commit --amend --no-edit
}

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
alias cop='copilot'

# Google Anty Gravity
alias agyyolo='agy --dangerously-skip-permissions'
