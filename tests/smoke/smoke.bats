#!/usr/bin/env bats

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    unset COPILOT_HOME
    if [ -f "$HOME/.profile" ]; then
        # shellcheck disable=SC1090,SC1091
        source "$HOME/.profile" 2>/dev/null || true
    fi
}

@test "Neovim is installed and runnable (v0.12.6)" {
    run nvim --version
    assert_success
    assert_output --partial "NVIM v0.12.6"
}

@test "Ripgrep is installed and runnable" {
    run rg --version
    assert_success
    assert_output --partial "ripgrep"
}

@test "Tree-sitter CLI is installed and runnable" {
    run tree-sitter --version
    assert_success
    assert_output --partial "tree-sitter"
}

@test "Python 3 is available in pyenv" {
    run python3 --version
    assert_success
    assert_output --partial "Python 3."
}

@test "Pyenv is installed and runnable" {
    run pyenv --version
    assert_success
    assert_output --partial "pyenv"
}

@test "Node.js is available via nvm" {
    run node --version
    assert_success
    assert_output --partial "v23."
}

@test "Git is installed and runnable" {
    run git --version
    assert_success
    assert_output --partial "git version"
}

@test "Docker CLI is installed and runnable" {
    run docker --version
    assert_success
    assert_output --partial "Docker version"
}

@test "Workstation user (not only root) belongs to docker group" {
    run id -nG "$(id -un)"
    assert_success
    assert_output --regexp '(^| )docker( |$)'
}

@test "Google Antigravity CLI is installed and runnable" {
    run agy --version
    assert_success
    assert_output
}

@test "GitHub Copilot CLI is installed and runnable" {
    run copilot --version
    assert_success
    assert_output --partial "GitHub Copilot CLI"
}

@test "Tmux is installed and runnable (v3.8)" {
    run tmux -V
    assert_success
    assert_output --partial "tmux 3.8"
}

@test "Neovim configuration exists and is non-empty" {
    assert_file_not_empty "$HOME/.config/nvim/init.lua"
    assert_dir_not_exists "$HOME/.config/nvim/tests"
}

@test "Bash aliases file exists and is non-empty" {
    assert_file_not_empty "$HOME/.bash_aliases"
}

@test "Tmux configuration exists and has focus-events enabled" {
    assert_file_not_empty "$HOME/.tmux.conf"
    run grep "set -g focus-events on" "$HOME/.tmux.conf"
    assert_success
}

@test "Global gitignore is configured and deployed" {
    assert_file_not_empty "$HOME/.gitignore_global"
    run git config --global core.excludesfile
    assert_success
    # shellcheck disable=SC2088
    assert_output "~/.gitignore_global"
}

@test "AI configuration is deployed to ~/.config/ai and discovered by Copilot CLI" {
    assert_file_not_empty "$HOME/.config/ai/AGENTS.md"
    assert_file_exists "$HOME/.config/ai/mcp-config.json"
    assert_file_permission 600 "$HOME/.config/ai/mcp-config.json"
    jq -e '.mcpServers.atlassian.command == "uvx"' "$HOME/.config/ai/mcp-config.json"
    jq -e '.mcpServers.atlassian.args[0] | startswith("mcp-atlassian==")' "$HOME/.config/ai/mcp-config.json"

    run copilot instruction list
    assert_success
    assert_output --partial "$HOME/.copilot/copilot-instructions.md"
    run copilot skill list
    assert_success
    assert_output --partial "conventional-commit"
    assert_output --partial "issue-author"
}

@test "GitHub Copilot CLI symlinks to ~/.config/ai exist" {
    assert_symlink_to "$HOME/.config/ai/skills" "$HOME/.copilot/skills"
    assert_symlink_to "$HOME/.config/ai/standards" "$HOME/.copilot/standards"
    assert_symlink_to "$HOME/.config/ai/agents" "$HOME/.copilot/agents"
    assert_symlink_to "$HOME/.config/ai/commands" "$HOME/.copilot/commands"
    assert_symlink_to "$HOME/.config/ai/mcp-config.json" "$HOME/.copilot/mcp-config.json"
    assert_symlink_to "$HOME/.config/ai/AGENTS.md" "$HOME/.copilot/copilot-instructions.md"
}

@test "Google Antigravity symlinks to ~/.config/ai exist" {
    assert_symlink_to "$HOME/.config/ai/skills" "$HOME/.gemini/config/skills"
    assert_symlink_to "$HOME/.config/ai/standards" "$HOME/.gemini/config/standards"
    assert_symlink_to "$HOME/.config/ai/agents" "$HOME/.gemini/config/agents"
    assert_symlink_to "$HOME/.config/ai/commands" "$HOME/.gemini/config/commands"
    assert_symlink_to "$HOME/.config/ai/mcp-config.json" "$HOME/.gemini/config/mcp_config.json"
    assert_symlink_to "$HOME/.config/ai/AGENTS.md" "$HOME/.gemini/config/GEMINI.md"
    assert_symlink_to "$HOME/.config/ai/AGENTS.md" "$HOME/.gemini/config/AGENTS.md"
}

@test "OpenCode symlinks to ~/.config/ai exist" {
    assert_symlink_to "$HOME/.config/ai/skills" "$HOME/.config/opencode/skills"
    assert_symlink_to "$HOME/.config/ai/standards" "$HOME/.config/opencode/standards"
    assert_symlink_to "$HOME/.config/ai/agents" "$HOME/.config/opencode/agents"
    assert_symlink_to "$HOME/.config/ai/commands" "$HOME/.config/opencode/commands"
    assert_symlink_to "$HOME/.config/ai/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
}

@test "PYENV_ROOT is exported in user profile" {
    run grep "export PYENV_ROOT=" "$HOME/.profile"
    assert_success
}

@test "NVM_DIR is exported in user profile" {
    run grep "export NVM_DIR=" "$HOME/.profile"
    assert_success
}

@test "Copilot has Maister plugin installed" {
    run copilot plugin list
    assert_success
    assert_output --partial "maister-copilot"
}

@test "Antigravity CLI has Maister plugin installed" {
    run agy plugin list
    assert_success
    assert_output --partial "maister"
    assert_output --partial "enabled"
}

@test "Docker compose plugin is installed and runnable" {
    run docker compose version
    assert_success
    assert_output --partial "Docker Compose version"
}

@test "Helm is installed and runnable" {
    run helm version
    assert_success
    assert_output --partial "version.BuildInfo"
}

@test "Lazygit is installed, runnable, and aliased to lg" {
    run lazygit --version
    assert_success
    assert_output --partial "version="
    run grep -qx "alias lg='lazygit'" "$HOME/.bash_aliases"
    assert_success
}

@test "uv and uvx binaries are installed and available in PATH" {
    command -v uv && command -v uvx
}

@test "Starship prompt is installed, runnable, and configured in Bash" {
    run command -v starship
    assert_success

    run starship --version
    assert_success
    assert_output --partial "starship"

    assert_file_not_empty "$HOME/.config/starship.toml"

    # shellcheck disable=SC2016
    run grep -F 'eval "$(starship init bash)"' "$HOME/.config/bash/init.sh"
    assert_success
}

@test "yq is installed and runnable" {
    run command -v yq
    assert_success
    assert_output --partial "yq"

    run yq --version
    assert_success
    assert_output --partial "yq (https://github.com/mikefarah/yq/)"
}

@test "Direnv is installed, runnable, and hooked into bashrc" {
    run command -v direnv
    assert_success
    run direnv version
    assert_success
    assert_output
    # shellcheck disable=SC2016
    run grep -F 'eval "$(direnv hook bash)"' "$HOME/.bashrc"
    assert_success
}

@test "fzf is installed and runnable" {
    run fzf --version
    assert_success
    assert_output
}

@test "fd and fdfind are installed and runnable" {
    run fd --version
    assert_success
    assert_output --partial "fd"
    run fdfind --version
    assert_success
    assert_output --partial "fd"
}

@test "zoxide is installed and runnable" {
    run zoxide --version
    assert_success
    assert_output --partial "zoxide"
}

@test "bat and batcat are installed and runnable" {
    run bat --version
    assert_success
    assert_output --partial "bat"
    run batcat --version
    assert_success
    assert_output --partial "bat"
}

@test "Bash init configures navigation tools, keybindings, and is sourced in bashrc" {
    assert_file_not_empty "$HOME/.config/bash/init.sh"
    run grep -q "fzf --bash" "$HOME/.config/bash/init.sh"
    assert_success
    run grep -q "zoxide init bash" "$HOME/.config/bash/init.sh"
    assert_success
    run grep -q "FZF_DEFAULT_COMMAND" "$HOME/.config/bash/init.sh"
    assert_success
    run grep -q "FZF_CTRL_T_OPTS" "$HOME/.config/bash/init.sh"
    assert_success
    run grep -q "if \[ -f ~/.config/bash/init.sh \]; then . ~/.config/bash/init.sh; fi" "$HOME/.bashrc"
    assert_success
}

@test "Tmux configuration enables mouse mode, OSC 52 clipboard pass-through, and True Color RGB" {
    assert_file_exists "$HOME/.tmux.conf"
    run grep -qx "set -g mouse on" "$HOME/.tmux.conf"
    assert_success
    run grep -qx "set -s set-clipboard on" "$HOME/.tmux.conf"
    assert_success
    run grep -q "terminal-features ',tmux-256color:clipboard'" "$HOME/.tmux.conf"
    assert_success
    run grep -q "terminal-features ',xterm-256color:clipboard'" "$HOME/.tmux.conf"
    assert_success
    run grep -q "terminal-features ',xterm-256color:RGB'" "$HOME/.tmux.conf"
    assert_success
    run grep -qx "set -g allow-passthrough on" "$HOME/.tmux.conf"
    assert_success
    run grep -Fq "bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-selection-no-clear" "$HOME/.tmux.conf"
    assert_success
    run grep -Fq "bind-key -T copy-mode-vi MouseDown1Pane select-pane \; send-keys -X clear-selection" "$HOME/.tmux.conf"
    assert_success
}

@test "Neovim initializes OSC 52 clipboard provider and unnamedplus" {
    run nvim --headless -c 'lua assert(vim.g.clipboard.name == "OSC 52", "OSC 52 provider missing"); assert(vim.opt.clipboard:get()[1] == "unnamedplus", "unnamedplus missing"); vim.fn.setreg("+", "clipboard_test")' -c 'q'
    assert_success
}

@test "Neovim plugins are pre-installed headlessly in lazy directory" {
    assert_dir_exists "$HOME/.local/share/nvim/lazy/plenary.nvim"
}
