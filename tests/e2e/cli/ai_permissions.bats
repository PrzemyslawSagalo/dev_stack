#!/usr/bin/env bats

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
    export PYTHONUSERBASE="${PYTHONUSERBASE:-$HOME/.local}"
    export HOME="$BATS_TEST_TMPDIR/home"
    export COPILOT_HOME="$BATS_TEST_TMPDIR/copilot-home"
    export ANSIBLE_ROLES_PATH="$REPO_DIR/roles"
    mkdir -p "$HOME" "$COPILOT_HOME"

    PLAYBOOK="$BATS_TEST_TMPDIR/ai-permissions.yml"
    cat >"$PLAYBOOK" <<'EOF'
---
- name: Deploy AI permissions for an isolated test home
  hosts: localhost
  connection: local
  gather_facts: true
  vars:
    ansible_python_interpreter: /usr/bin/python3
  tasks:
    - name: Configure AI permissions
      ansible.builtin.include_role:
        name: dotfiles
        tasks_from: ai_permissions.yml
EOF
}

@test "given a custom Copilot home, when deploying AI permissions, then the hook files are installed there" {
    run ansible-playbook -i localhost, -c local "$PLAYBOOK"
    assert_success
    assert_file_exists "$COPILOT_HOME/hooks/pre_tool_use.py"
    assert_file_exists "$COPILOT_HOME/hooks/permissions.json"
    assert_file_not_exists "$HOME/.copilot/hooks/pre_tool_use.py"
}

@test "given a commented JSONC OpenCode V1 config, when deploying permissions, then comments and trailing commas merge with ordered guards" {
    mkdir -p "$HOME/.config/opencode"
    cat >"$HOME/.config/opencode/opencode.jsonc" <<'EOF'
{
  // Keep the existing V1 settings.
  "permission": "allow",
  "custom": {"kept": true,},
}
EOF

    run ansible-playbook -i localhost, -c local "$PLAYBOOK"
    assert_success
    assert_file_permission 600 "$HOME/.config/opencode/opencode.jsonc"
    run jq -e '.custom.kept == true and .permission["*"] == "allow"' "$HOME/.config/opencode/opencode.jsonc"
    assert_success
    run jq -e '.permission.bash["*"] == "ask" and .permission.bash["git status"] == "allow" and .permission.bash["pre-commit run"] == "allow" and (.permission.bash | has("pre-commit") | not)' "$HOME/.config/opencode/opencode.jsonc"
    assert_success
    run jq -e '(.permission | keys_unsorted) as $keys | ($keys | index("*")) < ($keys | index("bash"))' "$HOME/.config/opencode/opencode.jsonc"
    assert_success
    run jq -e '.permission.bash["rg --pre"] == "ask" and .permission.bash["rg --pre *"] == "ask" and .permission.bash["rg --hostname-bin=*"] == "ask"' "$HOME/.config/opencode/opencode.jsonc"
    assert_success
    run jq -e '.permission.bash["git -P push"] == "deny" and .permission.bash["git -P push *"] == "deny" and .permission.bash["git -C* push"] == "deny" and .permission.bash["rm -Rf"] == "deny" and .permission.bash["rm -r -f"] == "deny"' "$HOME/.config/opencode/opencode.jsonc"
    assert_success
}

@test "given an OpenCode V2 permissions array, when deploying policy, then shell rules are replaced and unrelated rules remain" {
    mkdir -p "$HOME/.config/opencode"
    cat >"$HOME/.config/opencode/opencode.json" <<'EOF'
{
  "permissions": [
    {"action": "shell", "resource": "*", "effect": "allow"},
    {"action": "bash", "resource": "git push", "effect": "allow"},
    {"action": "read", "resource": "*", "effect": "allow"},
    {"action": "mcp", "resource": "server", "effect": "ask"}
  ]
}
EOF

    run ansible-playbook -i localhost, -c local "$PLAYBOOK"
    assert_success
    run jq -e 'any(.permissions[]; .action == "read" and .resource == "*" and .effect == "allow") and any(.permissions[]; .action == "mcp" and .resource == "server")' "$HOME/.config/opencode/opencode.json"
    assert_success
    run jq -e 'any(.permissions[]; .action == "shell" and .resource == "*" and .effect == "ask") and any(.permissions[]; .action == "shell" and .resource == "rg --pre" and .effect == "ask") and any(.permissions[]; .action == "shell" and .resource == "rg --pre *" and .effect == "ask")' "$HOME/.config/opencode/opencode.json"
    assert_success
    run jq -e 'any(.permissions[]; .action == "shell" and .resource == "git -P push" and .effect == "deny") and any(.permissions[]; .action == "shell" and .resource == "git status" and .effect == "allow") and any(.permissions[]; .action == "shell" and .resource == "pre-commit run" and .effect == "allow")' "$HOME/.config/opencode/opencode.json"
    assert_success
    run jq -e 'all(.permissions[]; .action != "bash" or .resource != "git push") and all(.permissions[]; .action != "shell" or .resource != "*" or .effect != "allow") and all(.permissions[]; .action != "shell" or .resource != "pre-commit")' "$HOME/.config/opencode/opencode.json"
    assert_success
}

@test "given existing Antigravity permissions, when deploying policy, then unrelated entries and non-conflicting asks remain" {
    mkdir -p "$HOME/.gemini/antigravity-cli"
    cat >"$HOME/.gemini/antigravity-cli/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["write_file(.git/)", "command(old command)"],
    "deny": ["write_file(.git/)", "command(old deny)"],
    "ask": ["read_file(secret)", "command(*)", "command(git status)", "command(rg --pre=*)", "command(regex:^git\\s+status)", "command(unknown command)"]
  }
}
EOF

    run ansible-playbook -i localhost, -c local "$PLAYBOOK"
    assert_success
    run jq -e '.permissions.allow | index("write_file(.git/)") != null and index("command(git status)") != null and index("command(pre-commit run)") != null and index("command(pre-commit)") == null' "$HOME/.gemini/antigravity-cli/settings.json"
    assert_success
    run jq -e '.permissions.deny | index("write_file(.git/)") != null and index("command(git -P push)") != null and index("command(rm -Rf)") != null and index("command(rm -r -f)") != null and index("command(regex:^git\\s+-C\\s+.*\\s+push(?:\\s+.*)?$)") != null and index("command(regex:^git\\s+-C.*\\s+push(?:\\s+.*)?$)") != null' "$HOME/.gemini/antigravity-cli/settings.json"
    assert_success
    run jq -e '.permissions.ask | index("read_file(secret)") != null and index("command(unknown command)") != null and index("command(rg --pre)") != null and index("command(regex:^rg\\s+--pre=.*$)") != null' "$HOME/.gemini/antigravity-cli/settings.json"
    assert_success
    run jq -e '.permissions.ask | index("command(*)") == null and index("command(git status)") == null and index("command(rg --pre=*)") == null and index("command(regex:^git\\s+status)") == null' "$HOME/.gemini/antigravity-cli/settings.json"
    assert_success
}

@test "given deployed Antigravity regex rules, when evaluating commands with Python regex matching, then restricted and denied variants match" {
    run ansible-playbook -i localhost, -c local "$PLAYBOOK"
    assert_success
    run python3 - "$HOME/.gemini/antigravity-cli/settings.json" <<'EOF'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    permissions = json.load(handle)["permissions"]

ask_regexes = [
    re.compile(rule[len("command(regex:"):-1])
    for rule in permissions["ask"]
    if rule.startswith("command(regex:")
]
deny_regexes = [
    re.compile(rule[len("command(regex:"):-1])
    for rule in permissions["deny"]
    if rule.startswith("command(regex:")
]

assert any(pattern.search("rg --pre=sh x") for pattern in ask_regexes)
assert any(pattern.search("git -C /repo push origin main") for pattern in deny_regexes)
assert any(pattern.search("git -C/repo push") for pattern in deny_regexes)
assert any(pattern.search("rm -R -v -f /tmp/x") for pattern in deny_regexes)
EOF
    assert_success
}
