#!/usr/bin/env bats

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK_SCRIPT="$REPO_DIR/roles/dotfiles/files/copilot/pre_tool_use.py"
    export AI_PERMISSIONS_FILE="$BATS_TEST_TMPDIR/permissions.json"
    cat >"$AI_PERMISSIONS_FILE" <<'EOF'
{
  "allow": ["git status", "rg", "ls", "echo"],
  "deny": ["git push", "rm -rf", "rm -fr", "sudo"]
}
EOF
}

@test "given a permitted command, when the hook receives it, then it allows the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"git status"}}
EOF

    assert_success
    assert_output '{"permissionDecision":"allow"}'
}

@test "given an unquoted environment variable in an allowed command, when the hook receives it, then it allows the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"echo $HOME"}}
EOF

    assert_success
    assert_output '{"permissionDecision":"allow"}'
}

@test "given an unquoted hash literal in an allowed command, when the hook receives it, then it allows the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"echo value#suffix"}}
EOF

    assert_success
    assert_output '{"permissionDecision":"allow"}'
}

@test "given json-string tool arguments with an allowed command, when the hook receives them, then it allows the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":"{\"command\":\"git status\"}"}
EOF

    assert_success
    assert_output '{"permissionDecision":"allow"}'
}

@test "given permitted commands joined by a pipe, when the hook receives them, then it allows the pipeline" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"git status | rg changed"}}
EOF

    assert_success
    assert_output '{"permissionDecision":"allow"}'
}

@test "given permitted commands joined by a newline, when the hook receives them, then it allows the commands" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"git status\necho hello"}}
EOF

    assert_success
    assert_output '{"permissionDecision":"allow"}'
}

@test "given a quoted denied pattern in an allowed search argument, when the hook receives it, then it allows the search" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"rg \"git push\" file.txt"}}
EOF

    assert_success
    assert_output '{"permissionDecision":"allow"}'
}

@test "given an allowed command in the background, when the hook receives it, then it emits no decision" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"echo hello &"}}
EOF

    assert_success
    assert_output ""
}

@test "given an allowed command using process substitution, when the hook receives it, then it emits no decision" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"echo <(echo hello)"}}
EOF

    assert_success
    assert_output ""
}

@test "given a matching subshell command rule, when the hook receives it, then it emits no decision" {
    cat >"$BATS_TEST_TMPDIR/subshell-permissions.json" <<'EOF'
{"allow":["(echo"],"deny":[]}
EOF

    run env AI_PERMISSIONS_FILE="$BATS_TEST_TMPDIR/subshell-permissions.json" python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"(echo hello)"}}
EOF

    assert_success
    assert_output ""
}

@test "given a denied command, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"git push origin main"}}
EOF

    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given a denied command in a chain, when the hook receives it, then it denies the chain" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"git status && rm -rf /tmp/x"}}
EOF

    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given a denied command prefixed by an environment assignment, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"FOO=1 git push"}}
EOF

    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given an unknown command, when the hook receives it, then it emits no decision" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"git commit -m update"}}
EOF

    assert_success
    assert_output ""
}

@test "given an unquoted command substitution, when the hook receives it, then it emits no decision" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"echo $(whoami)"}}
EOF

    assert_success
    assert_output ""
}

@test "given a single-quoted substitution literal, when an allowed search uses it, then the hook allows the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"rg '$(whoami)' file.txt"}}
EOF

    assert_success
    assert_output '{"permissionDecision":"allow"}'
}

@test "given a double-quoted command substitution, when the hook receives it, then it emits no decision" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"echo \"$(whoami)\""}}
EOF

    assert_success
    assert_output ""
}

@test "given an output redirection, when the hook receives it, then it emits no decision" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolName":"bash","toolArgs":{"command":"ls > /tmp/out"}}
EOF

    assert_success
    assert_output ""
}

@test "given a missing policy, when the hook receives a command, then it denies the command" {
    run env AI_PERMISSIONS_FILE="$BATS_TEST_TMPDIR/missing.json" python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"ls"}}
EOF
    assert_success
    assert_output '{"permissionDecision":"deny","permissionDecisionReason":"AI permissions policy is missing or invalid."}'
}

@test "given a malformed policy, when the hook receives a command, then it denies the command" {
    printf '%s\n' '{invalid' >"$BATS_TEST_TMPDIR/malformed.json"
    run env AI_PERMISSIONS_FILE="$BATS_TEST_TMPDIR/malformed.json" python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"ls"}}
EOF
    assert_success
    assert_output '{"permissionDecision":"deny","permissionDecisionReason":"AI permissions policy is missing or invalid."}'
}

@test "given the exact push command with an apostrophe in a comment, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"git push # don't retry"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given an assignment-only segment, when a later segment is denied, then the hook denies it" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"X=1; git push"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given a path assignment, when the hook receives an allowed command, then it emits no decision" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"PATH=./bin ls"}}
EOF
    assert_success
    assert_output ""
}

@test "given a git directory option, when the hook receives a push, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"git -C /repo push"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given separate recursive and force flags, when the hook receives rm, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"rm -r -f /tmp/x"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given an rg preprocessor flag, when the hook receives the command, then it emits no decision" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"rg --pre=sh x"}}
EOF
    assert_success
    assert_output ""
}

@test "given a backslash-newline in a denied Git command, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"git pu\\\nsh"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given a backslash-CRLF before a denied command, when the hook receives it, then it does not strip the line break and denies" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"echo ok\\\r\ngit push"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given a continued dangerous rg flag, when the hook receives it, then it does not allow the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"rg --pre=\\\nsh x"}}
EOF
    assert_success
    assert_output ""
}

@test "given an unresolved parameter expansion in an allowed search, when the hook receives it, then it does not allow the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"rg ${AI_REVIEW_UNSET:---pre=sh} x file.txt"}}
EOF
    assert_success
    assert_output ""
}

@test "given a brace expansion in an allowed search, when the hook receives it, then it does not allow the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"rg {--pre=sh,x} file.txt"}}
EOF
    assert_success
    assert_output ""
}

@test "given a quoted brace expansion literal, when an allowed search uses it, then the hook allows the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"rg '{a,b}' file.txt"}}
EOF
    assert_success
    assert_output '{"permissionDecision":"allow"}'
}

@test "given a carriage return before a comment marker, when a denied command follows, then the hook denies it" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"ls \r#; rm -rf /tmp/x"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given a command builtin wrapper around git push, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"command git push"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given a full executable path to git push, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"/usr/bin/git push"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given a git pager flag before push, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"git -P push"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given an attached git directory option before push, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"git -C/repo push"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given an env wrapper with an assignment before git push, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"env FOO=1 git push"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given the rg hostname-bin execution flag, when the hook receives it, then it does not allow the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"rg --hostname-bin=./x"}}
EOF
    assert_success
    assert_output ""
}

@test "given an ansi-c quoted argument, when the hook receives echo, then it emits no decision" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"echo $'hi'"}}
EOF
    assert_success
    assert_output ""
}

@test "given a comment ending with a backslash before a denied command, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"echo ok # comment\\\ngit push"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given an unquoted variable expansion in rg, when the hook receives it, then it emits no decision" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"rg $OPTIONS x file.txt"}}
EOF
    assert_success
    assert_output ""
}

@test "given a double-quoted variable expansion in rg, when the hook receives it, then it emits no decision" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"rg \"$OPTIONS\" x file.txt"}}
EOF
    assert_success
    assert_output ""
}

@test "given an unquoted glob in an allowed search command, when the hook receives it, then it emits no decision" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"rg TODO *"}}
EOF
    assert_success
    assert_output ""
}

@test "given a single-quoted glob literal in an allowed search command, when the hook receives it, then it allows the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"rg 'TODO*' file.txt"}}
EOF
    assert_success
    assert_output '{"permissionDecision":"allow"}'
}

@test "given an escaped glob character in an allowed search command, when the hook receives it, then it allows the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"rg TODO\\* file.txt"}}
EOF
    assert_success
    assert_output '{"permissionDecision":"allow"}'
}

@test "given a quoted heredoc containing a denied command string, when cat is allowed, then the hook allows the command" {
    cat >"$BATS_TEST_TMPDIR/cat-permissions.json" <<'EOF'
{"allow":["cat"],"deny":["git push"]}
EOF

    run env AI_PERMISSIONS_FILE="$BATS_TEST_TMPDIR/cat-permissions.json" python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"cat <<'EOF'\ngit push\nEOF"}}
EOF
    assert_success
    assert_output '{"permissionDecision":"allow"}'
}

@test "given an unquoted heredoc containing a denied command substitution, when the hook receives it, then it denies the command" {
    cat >"$BATS_TEST_TMPDIR/cat-permissions.json" <<'EOF'
{"allow":["cat"],"deny":["git push"]}
EOF

    run env AI_PERMISSIONS_FILE="$BATS_TEST_TMPDIR/cat-permissions.json" python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"cat <<EOF\n$(git push)\nEOF"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given a brace group wrapping a denied command, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"{ git push; }"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given a conditional branch containing a denied command, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"if true; then git push; fi"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given an exec wrapper around a denied command, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"exec git push"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given a custom denied glob pattern, when a command matches it, then the hook denies the command" {
    cat >"$BATS_TEST_TMPDIR/pattern-permissions.json" <<'EOF'
{"allow":["cat"],"deny":[],"denied_patterns":["cat *.key"]}
EOF

    run env AI_PERMISSIONS_FILE="$BATS_TEST_TMPDIR/pattern-permissions.json" python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"cat server.key"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given a custom multi-token deny rule, when a command matches it, then the hook denies the command" {
    cat >"$BATS_TEST_TMPDIR/key-deny-permissions.json" <<'EOF'
{"allow":["cat"],"deny":["cat server.key"]}
EOF

    run env AI_PERMISSIONS_FILE="$BATS_TEST_TMPDIR/key-deny-permissions.json" python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"cat server.key"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given a custom restricted pattern for an allowed command, when a command matches it, then the hook emits no decision" {
    cat >"$BATS_TEST_TMPDIR/restricted-permissions.json" <<'EOF'
{"allow":["rg"],"deny":[],"restricted_patterns":["rg --follow"]}
EOF

    run env AI_PERMISSIONS_FILE="$BATS_TEST_TMPDIR/restricted-permissions.json" python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"rg --follow x"}}
EOF
    assert_success
    assert_output ""
}

@test "given a double-quoted command substitution running a denied command, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"echo \"$(git push)\""}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given a backtick command substitution running a denied command, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"echo `git push`"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given a single-quoted command substitution literal in echo, when the hook receives it, then it allows the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"echo '$(git push)'"}}
EOF
    assert_success
    assert_output '{"permissionDecision":"allow"}'
}

@test "given an ansi-c quoted subcommand for a denied command, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"git $'push'"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}

@test "given an ansi-c quoted argument with an escaped quote in a denied command, when the hook receives it, then it denies the command" {
    run python3 "$HOOK_SCRIPT" <<'EOF'
{"toolArgs":{"command":"git push origin $'a\\'b'"}}
EOF
    assert_success
    assert_output --partial '"permissionDecision":"deny"'
}
