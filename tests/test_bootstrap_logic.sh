#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_SCRIPT="$REPO_ROOT/bootstrap.sh"

TEST_COUNT=0
PASS_COUNT=0

run_test() {
    local test_name="$1"
    shift
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "----------------------------------------"
    echo "Running Test ${TEST_COUNT}: ${test_name}"
    if "$@"; then
        echo "PASS: Test ${TEST_COUNT} - ${test_name}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: Test ${TEST_COUNT} - ${test_name}" >&2
        return 1
    fi
}

test_syntax() {
    bash -n "$BOOTSTRAP_SCRIPT"
}

test_in_repo_script_dir_detection() {
    local test_dir
    test_dir="$(mktemp -d)"

    local mock_bin="$test_dir/mock_bin"
    mkdir -p "$mock_bin"

    # Stub out apt-get so host package manager is never called on Debian/Ubuntu
    cat << 'EOF' > "$mock_bin/apt-get"
#!/bin/sh
exit 0
EOF
    cat << 'EOF' > "$mock_bin/sudo"
#!/bin/sh
exec "$@"
EOF
    cat << 'EOF' > "$mock_bin/dnf"
#!/bin/sh
exit 0
EOF
    cat << 'EOF' > "$mock_bin/git"
#!/bin/sh
echo "GIT_CALLED"
exit 0
EOF
    cat << 'EOF' > "$mock_bin/make"
#!/bin/sh
echo "MAKE_PWD=$PWD"
exit 0
EOF
    chmod +x "$mock_bin"/*

    # When invoking bootstrap.sh located in repo from an external directory, it must target the repo root
    local output
    output=$(cd "$test_dir" && PATH="$mock_bin:$PATH" bash "$BOOTSTRAP_SCRIPT" 2>&1)
    rm -rf "$test_dir"

    if ! echo "$output" | grep -q "MAKE_PWD=$REPO_ROOT"; then
        echo "Expected MAKE_PWD to be $REPO_ROOT, but got: $output" >&2
        return 1
    fi

    if echo "$output" | grep -q "GIT_CALLED"; then
        echo "Git should not be called in in-repo mode" >&2
        return 1
    fi
    return 0
}

test_in_repo_piped_detection() {
    local test_dir
    test_dir="$(mktemp -d)"

    touch "$test_dir/setup.yml"
    mkdir -p "$test_dir/roles/system"
    touch "$test_dir/Makefile"
    local mock_bin="$test_dir/mock_bin"
    mkdir -p "$mock_bin"

    # Stub out apt-get so host package manager is never called on Debian/Ubuntu
    cat << 'EOF' > "$mock_bin/apt-get"
#!/bin/sh
exit 0
EOF
    cat << 'EOF' > "$mock_bin/sudo"
#!/bin/sh
exec "$@"
EOF
    cat << 'EOF' > "$mock_bin/dnf"
#!/bin/sh
exit 0
EOF
    cat << 'EOF' > "$mock_bin/git"
#!/bin/sh
echo "GIT_CALLED"
exit 0
EOF
    cat << 'EOF' > "$mock_bin/make"
#!/bin/sh
echo "MAKE_PWD=$PWD"
exit 0
EOF
    chmod +x "$mock_bin"/*

    # When piped via stdin (curl | bash), it must detect ./setup.yml in current working directory
    local output
    output=$(cd "$test_dir" && PATH="$mock_bin:$PATH" bash < "$BOOTSTRAP_SCRIPT" 2>&1)
    rm -rf "$test_dir"

    if ! echo "$output" | grep -q "MAKE_PWD=$test_dir"; then
        echo "Expected MAKE_PWD to be $test_dir for piped execution, but got: $output" >&2
        return 1
    fi

    if echo "$output" | grep -q "GIT_CALLED"; then
        echo "Git should not be called in in-repo mode" >&2
        return 1
    fi
    return 0
}

test_standalone_cloning() {
    local test_dir
    test_dir="$(mktemp -d)"

    local mock_home="$test_dir/fake_home"
    mkdir -p "$mock_home"
    local mock_bin="$test_dir/mock_bin"
    mkdir -p "$mock_bin"

    # Stub out apt-get so host package manager is never called on Debian/Ubuntu
    cat << 'EOF' > "$mock_bin/apt-get"
#!/bin/sh
exit 0
EOF
    cat << 'EOF' > "$mock_bin/sudo"
#!/bin/sh
exec "$@"
EOF
    cat << 'EOF' > "$mock_bin/dnf"
#!/bin/sh
exit 0
EOF
    cat << 'EOF' > "$mock_bin/git"
#!/bin/sh
if [ "$1" = "clone" ]; then
    mkdir -p "$3"
fi
exit 0
EOF
    cat << 'EOF' > "$mock_bin/make"
#!/bin/sh
echo "MAKE_PWD=$PWD"
exit 0
EOF
    chmod +x "$mock_bin"/*

    # Piped execution outside of repo should trigger clone to $HOME/.dev_env
    local output
    output=$(cd "$test_dir" && HOME="$mock_home" PATH="$mock_bin:$PATH" bash < "$BOOTSTRAP_SCRIPT" 2>&1)
    local expected_dest="$mock_home/.dev_env"
    rm -rf "$test_dir"

    if ! echo "$output" | grep -q "MAKE_PWD=$expected_dest"; then
        echo "Expected MAKE_PWD to be $expected_dest, but got: $output" >&2
        return 1
    fi
    return 0
}

test_privilege_escalation_missing_sudo() {
    local test_dir
    test_dir="$(mktemp -d)"

    local mock_bin="$test_dir/mock_bin"
    mkdir -p "$mock_bin"

    cat << 'EOF' > "$mock_bin/id"
#!/bin/sh
if [ "$1" = "-u" ]; then
    echo "1000"
else
    /usr/bin/id "$@"
fi
EOF

    for cmd in bash dirname basename uname cut sed grep awk date echo cat mkdir rm mktemp; do
        target=$(command -v "$cmd" 2>/dev/null || true)
        if [ -n "$target" ] && [ -x "$target" ]; then
            ln -s "$target" "$mock_bin/$cmd"
        fi
    done
    chmod +x "$mock_bin/id"

    set +e
    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT" 2>&1)
    local exit_code=$?
    set -e
    rm -rf "$test_dir"

    if [ "$exit_code" -ne 1 ]; then
        echo "Expected exit code 1, got $exit_code. Output: $output" >&2
        return 1
    fi

    if ! echo "$output" | grep -qi "sudo.*not found\|install sudo\|run.*root"; then
        echo "Expected actionable error message about sudo, got: $output" >&2
        return 1
    fi
    return 0
}

test_microdnf_detection() {
    local test_dir
    test_dir="$(mktemp -d)"

    touch "$test_dir/setup.yml"
    local mock_bin="$test_dir/mock_bin"
    mkdir -p "$mock_bin"

    cat << 'EOF' > "$mock_bin/sudo"
#!/bin/sh
exec "$@"
EOF
    cat << 'EOF' > "$mock_bin/microdnf"
#!/bin/sh
echo "MICRODNF_CALLED: $@"
cat << 'DNFMOCK' > "$(dirname "$0")/dnf"
#!/bin/sh
exit 0
DNFMOCK
chmod +x "$(dirname "$0")/dnf"
exit 0
EOF
    cat << 'EOF' > "$mock_bin/make"
#!/bin/sh
exit 0
EOF
    cat << 'EOF' > "$mock_bin/ansible-playbook"
#!/bin/sh
exit 0
EOF
    chmod +x "$mock_bin"/*

    for cmd in bash dirname basename uname cut sed grep awk date echo cat mkdir rm mktemp id env chmod; do
        target=$(command -v "$cmd" 2>/dev/null || true)
        if [ -n "$target" ] && [ -x "$target" ]; then
            ln -s "$target" "$mock_bin/$cmd"
        fi
    done

    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT" 2>&1)
    rm -rf "$test_dir"

    if ! echo "$output" | grep -q "MICRODNF_CALLED: install -y git make python3 python3-pip dnf python3-dnf sudo"; then
        echo "Expected microdnf to install base packages, dnf bindings, and sudo, got: $output" >&2
        return 1
    fi
    return 0
}

test_unvalidated_workspace_not_hijacked() {
    local test_dir
    test_dir="$(mktemp -d)"

    # Create only setup.yml (without roles/system and Makefile)
    touch "$test_dir/setup.yml"

    local mock_home="$test_dir/fake_home"
    mkdir -p "$mock_home"
    local mock_bin="$test_dir/mock_bin"
    mkdir -p "$mock_bin"

    cat << 'EOF' > "$mock_bin/apt-get"
#!/bin/sh
exit 0
EOF
    cat << 'EOF' > "$mock_bin/sudo"
#!/bin/sh
exec "$@"
EOF
    cat << 'EOF' > "$mock_bin/dnf"
#!/bin/sh
exit 0
EOF
    cat << 'EOF' > "$mock_bin/git"
#!/bin/sh
if [ "$1" = "clone" ]; then
    echo "CLONING_REPO"
    mkdir -p "$3"
fi
exit 0
EOF
    cat << 'EOF' > "$mock_bin/make"
#!/bin/sh
echo "MAKE_PWD=$PWD"
exit 0
EOF
    chmod +x "$mock_bin"/*

    local output
    output=$(cd "$test_dir" && HOME="$mock_home" PATH="$mock_bin:$PATH" bash < "$BOOTSTRAP_SCRIPT" 2>&1)
    rm -rf "$test_dir"

    if ! echo "$output" | grep -q "CLONING_REPO"; then
        echo "Expected clone to be triggered when setup.yml lacks repo metadata, got: $output" >&2
        return 1
    fi
    if ! echo "$output" | grep -q "MAKE_PWD=$mock_home/.dev_env"; then
        echo "Expected MAKE_PWD to be $mock_home/.dev_env, got: $output" >&2
        return 1
    fi
    return 0
}

run_test "Bash syntax verification" test_syntax
run_test "In-repo workspace detection via script directory" test_in_repo_script_dir_detection
run_test "In-repo workspace detection via piped stdin (curl | bash)" test_in_repo_piped_detection
run_test "Unvalidated directory with setup.yml is not hijacked" test_unvalidated_workspace_not_hijacked
run_test "Standalone workspace cloning when setup.yml is missing" test_standalone_cloning
run_test "Privilege escalation error check (non-root without sudo)" test_privilege_escalation_missing_sudo
run_test "Microdnf package manager detection on minimal UBI" test_microdnf_detection

echo "========================================"
echo "All $PASS_COUNT / $TEST_COUNT logic tests passed successfully."
