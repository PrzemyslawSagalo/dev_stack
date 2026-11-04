#!/usr/bin/env bats

setup() {
    if [ -f "$HOME/.bashrc" ]; then
        # shellcheck disable=SC1090,SC1091
        source "$HOME/.bashrc" 2>/dev/null || true
    fi

    if [ -d "$HOME/.pyenv" ]; then
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init - 2>/dev/null)" || true
    fi

    export PATH="/usr/local/bin:/usr/local/go/bin:$PATH"
}

@test "Neovim is installed and runnable" {
    run nvim --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "NVIM v" ]]
}

@test "Ripgrep is installed and runnable" {
    run rg --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ripgrep" ]]
}

@test "Tree-sitter CLI is installed and runnable" {
    run tree-sitter --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tree-sitter" ]]
}

@test "Python 3 is available in pyenv" {
    run python3 --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Python 3."* ]]
}

@test "Git is installed and runnable" {
    run git --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "git version" ]]
}

@test "Docker CLI is installed and runnable" {
    run docker --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Docker version" ]]
}

@test "Google Antigravity CLI is installed and runnable" {
    run agy --version
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "Neovim configuration exists and is non-empty" {
    [ -s "$HOME/.config/nvim/init.lua" ]
}

@test "Bash aliases file exists and is non-empty" {
    [ -s "$HOME/.bash_aliases" ]
}

@test "Antigravity configuration symlinks to Copilot components exist" {
    [ -L "$HOME/.config/copilot/.mcp.json" ]
    [ -f "$HOME/.config/copilot/.mcp.json" ]
    [ -L "$HOME/.gemini/config/skills" ]
    [ -d "$HOME/.gemini/config/skills" ]
    [ -L "$HOME/.gemini/config/standards" ]
    [ -d "$HOME/.gemini/config/standards" ]
    [ -L "$HOME/.gemini/config/agents" ]
    [ -d "$HOME/.gemini/config/agents" ]
    [ -L "$HOME/.gemini/config/commands" ]
    [ -d "$HOME/.gemini/config/commands" ]
    [ -L "$HOME/.gemini/config/mcp_config.json" ]
    [ -f "$HOME/.gemini/config/mcp_config.json" ]
}
