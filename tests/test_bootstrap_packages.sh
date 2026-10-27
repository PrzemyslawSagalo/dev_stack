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

test_apt_path() {
    local test_dir
    test_dir="$(mktemp -d)"

    touch "$test_dir/setup.yml"
    local mock_bin="$test_dir/mock_bin"
    mkdir -p "$mock_bin"

    cat << 'EOF' > "$mock_bin/sudo"
#!/bin/sh
exec "$@"
EOF
    cat << 'EOF' > "$mock_bin/apt-get"
#!/bin/sh
echo "APT_CALLED: $@"
exit 0
EOF
    cat << 'EOF' > "$mock_bin/make"
#!/bin/sh
exit 0
EOF
    chmod +x "$mock_bin"/*

    for cmd in bash dirname basename uname cut sed grep awk date echo cat mkdir rm mktemp which id env; do
        target=$(command -v "$cmd" 2>/dev/null || true)
        if [ -n "$target" ] && [ -x "$target" ]; then
            ln -s "$target" "$mock_bin/$cmd"
        fi
    done

    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT")
    rm -rf "$test_dir"

    if ! echo "$output" | grep -q "APT_CALLED: update"; then
        echo "Expected apt-get update to be called, got: $output" >&2
        return 1
    fi

    if ! echo "$output" | grep -q "APT_CALLED: install -y git ansible make"; then
        echo "Expected apt-get install git ansible make, got: $output" >&2
        return 1
    fi
    return 0
}

test_rpm_base_packages() {
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
echo "DNF_CALLED: $@"
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

    for cmd in bash dirname basename uname cut sed grep awk date echo cat mkdir rm mktemp which id env; do
        target=$(command -v "$cmd" 2>/dev/null || true)
        if [ -n "$target" ] && [ -x "$target" ]; then
            ln -s "$target" "$mock_bin/$cmd"
        fi
    done

    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT")
    rm -rf "$test_dir"

    if ! echo "$output" | grep -q "DNF_CALLED: install -y git make python3 python3-pip"; then
        echo "Expected DNF to install base packages, got: $output" >&2
        return 1
    fi
    return 0
}

test_rpm_pip_fallback() {
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
if [ "$1" = "install" ] && echo "$@" | grep -q "ansible"; then
    # Simulate missing RPM packages
    exit 1
fi
echo "DNF_CALLED: $@"
exit 0
EOF
    cat << 'EOF' > "$mock_bin/python3"
#!/bin/sh
if [ "$1" = "-m" ] && [ "$2" = "pip" ]; then
    echo "PIP_CALLED: $@"
    exit 0
fi
exec /usr/bin/python3 "$@"
EOF
    cat << 'EOF' > "$mock_bin/make"
#!/bin/sh
exit 0
EOF
    chmod +x "$mock_bin"/*

    for cmd in bash dirname basename uname cut sed grep awk date echo cat mkdir rm mktemp which id env; do
        target=$(command -v "$cmd" 2>/dev/null || true)
        if [ -n "$target" ] && [ -x "$target" ]; then
            ln -s "$target" "$mock_bin/$cmd"
        fi
    done

    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT")
    rm -rf "$test_dir"

    if ! echo "$output" | grep -q "PIP_CALLED: -m pip install"; then
        echo "Expected python3 -m pip fallback, got: $output" >&2
        return 1
    fi
    return 0
}

test_path_enhancement() {
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
    cat << 'EOF' > "$mock_bin/ansible-playbook"
#!/bin/sh
exit 0
EOF
    cat << 'EOF' > "$mock_bin/make"
#!/bin/sh
echo "CHECK_PATH:$PATH"
exit 0
EOF
    chmod +x "$mock_bin"/*

    for cmd in bash dirname basename uname cut sed grep awk date echo cat mkdir rm mktemp which id env; do
        target=$(command -v "$cmd" 2>/dev/null || true)
        if [ -n "$target" ] && [ -x "$target" ]; then
            ln -s "$target" "$mock_bin/$cmd"
        fi
    done

    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT")
    rm -rf "$test_dir"

    if ! echo "$output" | grep -q ".local/bin"; then
        echo "Expected PATH to include .local/bin, got: $output" >&2
        return 1
    fi
    return 0
}

test_skip_ansible_when_already_installed() {
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
echo "DNF_CALLED: $@"
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

    for cmd in bash dirname basename uname cut sed grep awk date echo cat mkdir rm mktemp which id env; do
        target=$(command -v "$cmd" 2>/dev/null || true)
        if [ -n "$target" ] && [ -x "$target" ]; then
            ln -s "$target" "$mock_bin/$cmd"
        fi
    done

    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT")
    rm -rf "$test_dir"

    if echo "$output" | grep -q "Resolving Ansible installation"; then
        echo "Should not resolve Ansible when already installed, got: $output" >&2
        return 1
    fi

    if ! echo "$output" | grep -q "ansible-playbook already installed. Skipping installation"; then
        echo "Expected skip message, got: $output" >&2
        return 1
    fi
    return 0
}

run_test "Debian/Ubuntu package installation flow" test_apt_path
run_test "RPM base package installation" test_rpm_base_packages
run_test "RPM 3-tier fallback to python3 -m pip install" test_rpm_pip_fallback
run_test "PATH export and enhancement before make setup" test_path_enhancement
run_test "Skip Ansible installation if already present" test_skip_ansible_when_already_installed

echo "========================================"
echo "All $PASS_COUNT / $TEST_COUNT package tests passed successfully."
