#!/usr/bin/env bats

setup() {
    if [ -f "$HOME/.profile" ]; then
        # shellcheck disable=SC1090,SC1091
        source "$HOME/.profile" 2>/dev/null || true
    fi
}

@test "Neovim is installed and runnable (v0.12.6)" {
    run nvim --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"NVIM v0.12.6"* ]]
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

@test "Pyenv is installed and runnable" {
    run pyenv --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "pyenv" ]]
}

@test "Node.js is available via nvm" {
    run node --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"v23."* ]]
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

@test "GitHub Copilot CLI is installed and runnable" {
    run copilot --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "GitHub Copilot CLI" ]]
}

@test "Tmux is installed and runnable (v3.8)" {
    run tmux -V
    [ "$status" -eq 0 ]
    [[ "$output" == *"tmux 3.8"* ]]
}

@test "Neovim configuration exists and is non-empty" {
    [ -s "$HOME/.config/nvim/init.lua" ]
}

@test "Neovim configuration has no orphaned files or directories" {
    [ ! -e "$HOME/.config/nvim/.managed_manifest.json" ]
    [ ! -e "$HOME/.config/nvim/lua/plugins/diffview.lua" ]
    [ ! -d "$HOME/.config/nvim/tests" ]
}

@test "Bash aliases file exists and is non-empty" {
    [ -s "$HOME/.bash_aliases" ]
}

@test "Tmux configuration exists and has focus-events enabled" {
    [ -s "$HOME/.tmux.conf" ]
    run grep "set -g focus-events on" "$HOME/.tmux.conf"
    [ "$status" -eq 0 ]
}

@test "Antigravity configuration symlinks to Copilot components exist" {
    [ -f "$HOME/.copilot/.mcp.json" ]
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

@test "PYENV_ROOT is exported in user profile" {
    run grep "export PYENV_ROOT=" "$HOME/.profile"
    [ "$status" -eq 0 ]
}

@test "NVM_DIR is exported in user profile" {
    run grep "export NVM_DIR=" "$HOME/.profile"
    [ "$status" -eq 0 ]
}

@test "Copilot has Maister plugin installed" {
    run copilot plugin list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "maister-copilot" ]]
}

@test "Antigravity CLI has Maister plugin installed" {
    run agy plugin list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "maister" ]]
    [[ "$output" =~ "enabled" ]]
}
