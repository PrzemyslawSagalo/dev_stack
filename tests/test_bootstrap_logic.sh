#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_SCRIPT="$REPO_ROOT/bootstrap.sh"

# Source shared test helpers
# shellcheck source=tests/test_helpers.sh
source "$REPO_ROOT/tests/test_helpers.sh"

test_syntax() {
    bash -n "$BOOTSTRAP_SCRIPT"
    sh -n "$BOOTSTRAP_SCRIPT"
    bash -n "$REPO_ROOT/tests/test_helpers.sh"
    sh -n "$REPO_ROOT/tests/test_helpers.sh"
}

test_in_repo_script_dir_detection() {
    local test_dir
    test_dir="$(mktemp -d)"
    trap 'rm -rf "${test_dir:-}"' RETURN

    local mock_bin="$test_dir/mock_bin"
    mock_pkg_mgr "$mock_bin" "apt-get"
    mock_pkg_mgr "$mock_bin" "dnf"
    mock_sudo "$mock_bin"
    create_mock "$mock_bin" "git" 'echo "GIT_CALLED"; exit 0'
    mock_make "$mock_bin" true

    # When invoking bootstrap.sh located in repo from an external directory, it must target the repo root
    local output
    output=$(cd "$test_dir" && PATH="$mock_bin:$PATH" bash "$BOOTSTRAP_SCRIPT" 2>&1)

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
    trap 'rm -rf "${test_dir:-}"' RETURN

    setup_repo_workspace "$test_dir"
    local mock_bin="$test_dir/mock_bin"
    mock_pkg_mgr "$mock_bin" "apt-get"
    mock_pkg_mgr "$mock_bin" "dnf"
    mock_sudo "$mock_bin"
    create_mock "$mock_bin" "git" 'echo "GIT_CALLED"; exit 0'
    mock_make "$mock_bin" true

    # When piped via stdin (curl | bash), it must detect ./setup.yml in current working directory
    local output
    output=$(cd "$test_dir" && PATH="$mock_bin:$PATH" bash < "$BOOTSTRAP_SCRIPT" 2>&1)

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
    trap 'rm -rf "${test_dir:-}"' RETURN

    local mock_home="$test_dir/fake_home"
    mkdir -p "$mock_home"
    local mock_bin="$test_dir/mock_bin"

    mock_pkg_mgr "$mock_bin" "apt-get"
    mock_pkg_mgr "$mock_bin" "dnf"
    mock_sudo "$mock_bin"
    create_mock "$mock_bin" "git" 'if [ "$1" = "clone" ]; then mkdir -p "$3"; fi; exit 0'
    mock_make "$mock_bin" true

    # Piped execution outside of repo should trigger clone to $HOME/.dev_env
    local output
    output=$(cd "$test_dir" && HOME="$mock_home" PATH="$mock_bin:$PATH" bash < "$BOOTSTRAP_SCRIPT" 2>&1)
    local expected_dest="$mock_home/.dev_env"

    if ! echo "$output" | grep -q "MAKE_PWD=$expected_dest"; then
        echo "Expected MAKE_PWD to be $expected_dest, but got: $output" >&2
        return 1
    fi
    return 0
}

test_privilege_escalation_missing_sudo() {
    local test_dir
    test_dir="$(mktemp -d)"
    trap 'rm -rf "${test_dir:-}"' RETURN

    local mock_bin="$test_dir/mock_bin"
    local real_id
    real_id="$(command -v id)"
    create_mock "$mock_bin" "id" "if [ \"\$1\" = \"-u\" ]; then
    echo \"1000\"
else
    $real_id \"\$@\"
fi"
    link_coreutils "$mock_bin"

    set +e
    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT" 2>&1)
    local exit_code=$?
    set -e

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
    trap 'rm -rf "${test_dir:-}"' RETURN

    touch "$test_dir/setup.yml"
    local mock_bin="$test_dir/mock_bin"

    mock_sudo "$mock_bin"
    mock_microdnf "$mock_bin"
    mock_make "$mock_bin" false
    mock_ansible_playbook "$mock_bin"
    link_coreutils "$mock_bin"

    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT" 2>&1)

    if ! echo "$output" | grep -q "MICRODNF_CALLED: install -y git make python3 python3-pip dnf python3-dnf sudo"; then
        echo "Expected microdnf to install base packages, dnf bindings, and sudo, got: $output" >&2
        return 1
    fi
    return 0
}

test_unvalidated_workspace_not_hijacked() {
    local test_dir
    test_dir="$(mktemp -d)"
    trap 'rm -rf "${test_dir:-}"' RETURN

    # Create only setup.yml (without roles/system and Makefile)
    touch "$test_dir/setup.yml"

    local mock_home="$test_dir/fake_home"
    mkdir -p "$mock_home"
    local mock_bin="$test_dir/mock_bin"

    mock_pkg_mgr "$mock_bin" "apt-get"
    mock_pkg_mgr "$mock_bin" "dnf"
    mock_sudo "$mock_bin"
    create_mock "$mock_bin" "git" 'if [ "$1" = "clone" ]; then
    echo "CLONING_REPO"
    mkdir -p "$3"
fi
exit 0'
    mock_make "$mock_bin" true

    local output
    output=$(cd "$test_dir" && HOME="$mock_home" PATH="$mock_bin:$PATH" bash < "$BOOTSTRAP_SCRIPT" 2>&1)

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

test_corrupted_git_dir_recreated() {
    local test_dir
    test_dir="$(mktemp -d)"
    trap 'rm -rf "${test_dir:-}"' RETURN

    local mock_home="$test_dir/fake_home"
    mkdir -p "$mock_home/.dev_env"  # Directory exists but lacks .git (corrupt/partial clone)

    local mock_bin="$test_dir/mock_bin"
    mock_pkg_mgr "$mock_bin" "apt-get"
    mock_pkg_mgr "$mock_bin" "dnf"
    mock_sudo "$mock_bin"
    create_mock "$mock_bin" "git" 'if [ "$1" = "clone" ]; then
    echo "CLONE_CALLED"
    mkdir -p "$3/.git"
fi
exit 0'
    mock_make "$mock_bin" true

    local output
    output=$(cd "$test_dir" && HOME="$mock_home" PATH="$mock_bin:$PATH" bash < "$BOOTSTRAP_SCRIPT" 2>&1)

    if ! echo "$output" | grep -q "CLONE_CALLED"; then
        echo "Expected clone to be called when .dev_env lacks .git, got: $output" >&2
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
run_test "Corrupted or non-git destination directory is cleaned and re-cloned" test_corrupted_git_dir_recreated
run_test "Standalone workspace cloning when setup.yml is missing" test_standalone_cloning
run_test "Privilege escalation error check (non-root without sudo)" test_privilege_escalation_missing_sudo
run_test "Microdnf package manager detection on minimal UBI" test_microdnf_detection

echo "========================================"
echo "All $PASS_COUNT / $TEST_COUNT logic tests passed successfully."
