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
    [ ! -d "$HOME/.config/nvim/tests" ]
}

@test "Neovim configuration purges orphaned files and directories" {
    local repo_root
    repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    mkdir -p "$HOME/.config/nvim/orphan_dir"
    touch "$HOME/.config/nvim/lua/core/orphan_plugin.lua"
    touch "$HOME/.config/nvim/orphan_dir/stale.lua"
    ln -sf /tmp/nonexistent_orphan_target "$HOME/.config/nvim/lua/core/orphan_link.lua"
    rm -rf "$HOME/.config/nvim/lua/plugins"
    ln -s /tmp/nonexistent_orphan_target "$HOME/.config/nvim/lua/plugins"
    rm -rf "$HOME/.config/nvim/init.lua"
    mkdir "$HOME/.config/nvim/init.lua"

    run ansible-playbook -i localhost, -c local "$repo_root/setup.yml" --tags nvim
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.config/nvim/lua/core/orphan_plugin.lua" ]
    [ ! -L "$HOME/.config/nvim/lua/core/orphan_link.lua" ]
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

@test "Global gitignore is configured and deployed" {
    [ -s "$HOME/.gitignore_global" ]
    run git config --global core.excludesfile
    [ "$status" -eq 0 ]
    # shellcheck disable=SC2088
    [ "$output" = "~/.gitignore_global" ]
}

@test "Antigravity configuration symlinks to Copilot components exist" {
    [ -s "$HOME/.copilot/copilot-instructions.md" ]
    [ -f "$HOME/.copilot/mcp-config.json" ]
    [ -L "$HOME/.gemini/config/skills" ]
    [ -d "$HOME/.gemini/config/skills" ]
    [ "$(readlink -f "$HOME/.gemini/config/skills")" = "$HOME/.copilot/skills" ]
    [ -L "$HOME/.gemini/config/standards" ]
    [ -d "$HOME/.gemini/config/standards" ]
    [ "$(readlink -f "$HOME/.gemini/config/standards")" = "$HOME/.copilot/standards" ]
    [ -L "$HOME/.gemini/config/agents" ]
    [ -d "$HOME/.gemini/config/agents" ]
    [ "$(readlink -f "$HOME/.gemini/config/agents")" = "$HOME/.copilot/agents" ]
    [ -L "$HOME/.gemini/config/commands" ]
    [ -d "$HOME/.gemini/config/commands" ]
    [ "$(readlink -f "$HOME/.gemini/config/commands")" = "$HOME/.copilot/commands" ]
    [ -L "$HOME/.gemini/config/mcp_config.json" ]
    [ -f "$HOME/.gemini/config/mcp_config.json" ]
    [ "$(readlink -f "$HOME/.gemini/config/mcp_config.json")" = "$HOME/.copilot/mcp-config.json" ]
    [ "$(stat -c "%a" "$HOME/.copilot/mcp-config.json")" = "600" ]
    jq -e '.mcpServers.atlassian.command == "uvx"' "$HOME/.copilot/mcp-config.json"
    jq -e '.mcpServers.atlassian.args[0] | startswith("mcp-atlassian==")' "$HOME/.copilot/mcp-config.json"
    [ -L "$HOME/.gemini/config/GEMINI.md" ]
    [ -f "$HOME/.gemini/config/GEMINI.md" ]
    [ -L "$HOME/.gemini/config/AGENTS.md" ]
    [ -f "$HOME/.gemini/config/AGENTS.md" ]
    [ "$(readlink -f "$HOME/.gemini/config/GEMINI.md")" = "$HOME/.copilot/copilot-instructions.md" ]
    [ "$(readlink -f "$HOME/.gemini/config/AGENTS.md")" = "$HOME/.copilot/copilot-instructions.md" ]
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

@test "uv and uvx binaries are installed and available in PATH" {
    command -v uv && command -v uvx
}

@test "Starship prompt is installed, runnable, and configured in Bash" {
    run command -v starship
    [ "$status" -eq 0 ]

    run starship --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "starship" ]]

    [ -s "$HOME/.config/starship.toml" ]

    # shellcheck disable=SC2016
    run grep -F 'eval "$(starship init bash)"' "$HOME/.config/bash/init.sh"
    [ "$status" -eq 0 ]
}

@test "yq is installed and runnable" {
    run command -v yq
    [ "$status" -eq 0 ]
    [[ "$output" == *"yq"* ]]

    run yq --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"yq (https://github.com/mikefarah/yq/)"* ]]
}

@test "Direnv is installed, runnable, and hooked into bashrc" {
    run command -v direnv
    [ "$status" -eq 0 ]
    run direnv version
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # shellcheck disable=SC2016
    run grep -F 'eval "$(direnv hook bash)"' "$HOME/.bashrc"
    [ "$status" -eq 0 ]
}

@test "fzf is installed and runnable" {
    run fzf --version
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "fd and fdfind are installed and runnable" {
    run fd --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "fd" ]]
    run fdfind --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "fd" ]]
}

@test "zoxide is installed and runnable" {
    run zoxide --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "zoxide" ]]
}

@test "bat and batcat are installed and runnable" {
    run bat --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "bat" ]]
    run batcat --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "bat" ]]
}

@test "Bash init configures navigation tools, keybindings, and is sourced in bashrc" {
    [ -s "$HOME/.config/bash/init.sh" ]
    run grep -q "fzf --bash" "$HOME/.config/bash/init.sh"
    [ "$status" -eq 0 ]
    run grep -q "zoxide init bash" "$HOME/.config/bash/init.sh"
    [ "$status" -eq 0 ]
    run grep -q "FZF_DEFAULT_COMMAND" "$HOME/.config/bash/init.sh"
    [ "$status" -eq 0 ]
    run grep -q "FZF_CTRL_T_OPTS" "$HOME/.config/bash/init.sh"
    [ "$status" -eq 0 ]
    run grep -q "if \[ -f ~/.config/bash/init.sh \]; then . ~/.config/bash/init.sh; fi" "$HOME/.bashrc"
    [ "$status" -eq 0 ]
}

@test "Tmux configuration enables mouse mode, OSC 52 clipboard pass-through, True Color RGB, and aggressive-resize" {
    [ -f "$HOME/.tmux.conf" ]
    run grep -qx "set -g mouse on" "$HOME/.tmux.conf"
    [ "$status" -eq 0 ]
    run grep -qx "set -s set-clipboard on" "$HOME/.tmux.conf"
    [ "$status" -eq 0 ]
    run grep -q "terminal-features ',tmux-256color:clipboard'" "$HOME/.tmux.conf"
    [ "$status" -eq 0 ]
    run grep -q "terminal-features ',xterm-256color:clipboard'" "$HOME/.tmux.conf"
    [ "$status" -eq 0 ]
    run grep -q "terminal-features ',xterm-256color:RGB'" "$HOME/.tmux.conf"
    [ "$status" -eq 0 ]
    run grep -qx "set -g allow-passthrough on" "$HOME/.tmux.conf"
    [ "$status" -eq 0 ]
    run grep -qx "set-window-option -g aggressive-resize on" "$HOME/.tmux.conf"
    [ "$status" -eq 0 ]
    run grep -Fq "bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-selection-no-clear" "$HOME/.tmux.conf"
    [ "$status" -eq 0 ]
    run grep -Fq "bind-key -T copy-mode-vi MouseDown1Pane select-pane \; send-keys -X clear-selection" "$HOME/.tmux.conf"
    [ "$status" -eq 0 ]
}

@test "Neovim initializes OSC 52 clipboard provider and unnamedplus" {
    run nvim --headless -c 'lua assert(vim.g.clipboard.name == "OSC 52", "OSC 52 provider missing"); assert(vim.opt.clipboard:get()[1] == "unnamedplus", "unnamedplus missing"); vim.fn.setreg("+", "clipboard_test")' -c 'q'
    [ "$status" -eq 0 ]
}

@test "Neovim plugins are pre-installed headlessly in lazy directory" {
    [ -d "$HOME/.local/share/nvim/lazy/plenary.nvim" ]
}
