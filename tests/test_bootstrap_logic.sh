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

test_in_repo_detection() {
    local test_dir
    test_dir="$(mktemp -d)"

    touch "$test_dir/setup.yml"
    local mock_bin="$test_dir/mock_bin"
    mkdir -p "$mock_bin"

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
echo "GIT_CALLED" >&2
exit 0
EOF
    cat << 'EOF' > "$mock_bin/make"
#!/bin/sh
echo "MAKE_PWD=$PWD"
exit 0
EOF
    chmod +x "$mock_bin"/*

    local output
    output=$(cd "$test_dir" && PATH="$mock_bin:$PATH" bash "$BOOTSTRAP_SCRIPT")
    rm -rf "$test_dir"

    if ! echo "$output" | grep -q "MAKE_PWD=$test_dir"; then
        echo "Expected MAKE_PWD to be $test_dir, but got: $output" >&2
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

    # Simulate standalone bootstrap.sh downloaded outside repo
    cp "$BOOTSTRAP_SCRIPT" "$test_dir/bootstrap.sh"

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

    local output
    output=$(cd "$test_dir" && HOME="$mock_home" PATH="$mock_bin:$PATH" bash "$test_dir/bootstrap.sh")
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

run_test "Bash syntax verification" test_syntax
run_test "In-repo workspace detection when ./setup.yml is present" test_in_repo_detection
run_test "Standalone workspace cloning when ./setup.yml is missing" test_standalone_cloning
run_test "Privilege escalation error check (non-root without sudo)" test_privilege_escalation_missing_sudo

echo "========================================"
echo "All $PASS_COUNT / $TEST_COUNT logic tests passed successfully."
