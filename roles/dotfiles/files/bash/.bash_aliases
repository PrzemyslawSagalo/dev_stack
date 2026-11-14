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

# Tmux
alias tnwc='tmux new-window -c $(pwd)'
tj() {
    if [ -n "${TMUX:-}" ]; then
        echo "Error: already inside a tmux session" >&2
        return 1
    fi

    local target="${1:-}"
    if [ -z "$target" ]; then
        local sessions count
        sessions="$(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)"
        count="$(printf '%s\n' "$sessions" | grep -c . || true)"
        if [ "$count" -eq 0 ]; then
            echo "Error: no active tmux sessions found" >&2
            return 1
        elif [ "$count" -eq 1 ]; then
            target="$sessions"
        else
            if command -v fzf >/dev/null 2>&1; then
                target="$(printf '%s\n' "$sessions" | fzf --prompt="tmux session> ")"
                if [ -z "$target" ]; then
                    return 1
                fi
            else
                echo "Error: multiple sessions exist. Specify target session:" >&2
                printf '%s\n' "$sessions" >&2
                return 1
            fi
        fi
    fi

    if ! tmux has-session -t "$target" 2>/dev/null; then
        echo "Error: tmux session '$target' does not exist" >&2
        return 1
    fi

    local grouped="${target}-mon-$$"
    tmux new-session -d -s "$grouped" -t "$target"
    tmux set-hook -t "$grouped" client-attached 'set-option destroy-unattached on'
    local win_id
    while IFS= read -r win_id; do
        [ -n "$win_id" ] && tmux set-window-option -t "$win_id" aggressive-resize on
    done < <(tmux list-windows -t "$grouped" -F '#{window_id}')
    tmux attach-session -t "$grouped"
}

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
