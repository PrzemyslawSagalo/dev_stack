#!/usr/bin/env bats

setup() {
    unset COPILOT_HOME
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

@test "Workstation user (not only root) belongs to docker group" {
    run id -nG "$(id -un)"
    [ "$status" -eq 0 ]
    [[ " $output " == *" docker "* ]]
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

@test "Neovim configuration purges orphaned files and directories" {
    local repo_root
    repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    mkdir -p "$HOME/.config/nvim/orphan_dir"
    touch "$HOME/.config/nvim/lua/core/orphan_plugin.lua"
    touch "$HOME/.config/nvim/orphan_dir/stale.lua"
    ln -sf /tmp/nonexistent_orphan_target "$HOME/.config/nvim/lua/utils/orphan_link.lua"
    rm -rf "$HOME/.config/nvim/lua/plugins"
    ln -s /tmp/nonexistent_orphan_target "$HOME/.config/nvim/lua/plugins"
    rm -rf "$HOME/.config/nvim/init.lua"
    mkdir "$HOME/.config/nvim/init.lua"

    run ansible-playbook -i localhost, -c local "$repo_root/setup.yml" --tags nvim
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.config/nvim/lua/core/orphan_plugin.lua" ]
    [ ! -L "$HOME/.config/nvim/lua/utils/orphan_link.lua" ]
    [ ! -d "$HOME/.config/nvim/orphan_dir" ]
    [ -d "$HOME/.config/nvim/lua/plugins" ]
    [ ! -L "$HOME/.config/nvim/lua/plugins" ]
    [ -f "$HOME/.config/nvim/init.lua" ]

    run diff -rq "$repo_root/roles/nvim/files/nvim" "$HOME/.config/nvim"
    [ "$status" -eq 0 ]
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
    [ -f "$HOME/.copilot/mcp-config.json" ]
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
    [ "$(readlink -f "$HOME/.gemini/config/mcp_config.json")" = "$HOME/.copilot/mcp-config.json" ]
    [ "$(stat -c "%a" "$HOME/.copilot/mcp-config.json")" = "600" ]
    [ -L "$HOME/.gemini/config/GEMINI.md" ]
    [ -f "$HOME/.gemini/config/GEMINI.md" ]
    [ -L "$HOME/.gemini/config/AGENTS.md" ]
    [ -f "$HOME/.gemini/config/AGENTS.md" ]
    [ "$(readlink -f "$HOME/.gemini/config/GEMINI.md")" = "$HOME/.copilot/copilot-instructions.md" ]
    [ "$(readlink -f "$HOME/.gemini/config/AGENTS.md")" = "$HOME/.copilot/copilot-instructions.md" ]
    run grep "Subagent & Model Routing Policy" "$HOME/.copilot/copilot-instructions.md"
    [ "$status" -eq 0 ]
    run grep "Subagent & Model Routing Policy" "$HOME/.gemini/config/GEMINI.md"
    [ "$status" -eq 0 ]
    run grep "Subagent & Model Routing Policy" "$HOME/.gemini/config/AGENTS.md"
    [ "$status" -eq 0 ]
    run copilot instruction list
    [ "$status" -eq 0 ]
    [[ "$output" == *"$HOME/.copilot/copilot-instructions.md"* ]]
    run copilot skill list
    [ "$status" -eq 0 ]
    [[ "$output" == *"conventional-commit"* ]]
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

@test "Docker compose plugin is installed and runnable" {
    run docker compose version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Docker Compose version"* ]]
}

@test "Helm is installed and runnable" {
    run helm version
    [ "$status" -eq 0 ]
    [[ "$output" == *"version.BuildInfo"* ]]
}

@test "Lazygit is installed, runnable, and aliased to lg" {
    run lazygit --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"version="* ]]
    run grep -qx "alias lg='lazygit'" "$HOME/.bash_aliases"
    [ "$status" -eq 0 ]
}
