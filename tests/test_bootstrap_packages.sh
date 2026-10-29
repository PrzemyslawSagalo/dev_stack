#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_SCRIPT="$REPO_ROOT/bootstrap.sh"

# Source shared test helpers
# shellcheck source=tests/test_helpers.sh
source "$REPO_ROOT/tests/test_helpers.sh"

test_apt_path() {
    local test_dir
    test_dir="$(mktemp -d)"
    trap 'rm -rf "${test_dir:-}"' RETURN

    setup_repo_workspace "$test_dir"
    local mock_bin="$test_dir/mock_bin"

    mock_sudo "$mock_bin"
    mock_pkg_mgr "$mock_bin" "apt-get" log
    mock_make "$mock_bin" false
    mock_ansible_playbook "$mock_bin"
    link_coreutils "$mock_bin"

    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT" 2>&1)

    if ! echo "$output" | grep -q "APT_CALLED: update"; then
        echo "Expected apt-get update to be called, got: $output" >&2
        return 1
    fi

    if ! echo "$output" | grep -q "APT_CALLED: install -y git make python3 python3-pip sudo bash"; then
        echo "Expected apt-get install git make python3 python3-pip sudo bash, got: $output" >&2
        return 1
    fi
    return 0
}

test_rpm_base_packages() {
    local test_dir
    test_dir="$(mktemp -d)"
    trap 'rm -rf "${test_dir:-}"' RETURN

    setup_repo_workspace "$test_dir"
    local mock_bin="$test_dir/mock_bin"

    mock_sudo "$mock_bin"
    mock_pkg_mgr "$mock_bin" "dnf" log
    mock_make "$mock_bin" false
    mock_ansible_playbook "$mock_bin"
    link_coreutils "$mock_bin"

    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT" 2>&1)

    if ! echo "$output" | grep -q "DNF_CALLED: install -y git make python3 python3-pip sudo bash"; then
        echo "Expected DNF to install base packages with sudo and bash, got: $output" >&2
        return 1
    fi
    return 0
}

test_microdnf_base_packages() {
    local test_dir
    test_dir="$(mktemp -d)"
    trap 'rm -rf "${test_dir:-}"' RETURN

    setup_repo_workspace "$test_dir"
    local mock_bin="$test_dir/mock_bin"

    mock_sudo "$mock_bin"
    mock_microdnf "$mock_bin"
    mock_make "$mock_bin" false
    mock_ansible_playbook "$mock_bin"
    link_coreutils "$mock_bin"

    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT" 2>&1)

    if ! echo "$output" | grep -q "MICRODNF_CALLED: install -y git make python3 python3-pip dnf python3-dnf sudo bash"; then
        echo "Expected microdnf to install base packages including dnf, python3-dnf, sudo, and bash, got: $output" >&2
        return 1
    fi
    return 0
}

test_rpm_pip_fallback() {
    local test_dir
    test_dir="$(mktemp -d)"
    trap 'rm -rf "${test_dir:-}"' RETURN

    setup_repo_workspace "$test_dir"
    local mock_bin="$test_dir/mock_bin"
    local real_py
    real_py="$(command -v python3)"

    mock_sudo "$mock_bin"
    mock_pkg_mgr "$mock_bin" "dnf" fail-ansible
    create_mock "$mock_bin" "python3" "if [ \"\$1\" = \"-m\" ] && [ \"\$2\" = \"pip\" ]; then
    echo \"PIP_CALLED: \$@\"
    exit 0
fi
exec $real_py \"\$@\""
    mock_make "$mock_bin" false
    link_coreutils "$mock_bin"

    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT" 2>&1)

    if ! echo "$output" | grep -q "PIP_CALLED: -m pip install"; then
        echo "Expected python3 -m pip fallback, got: $output" >&2
        return 1
    fi
    return 0
}

test_apt_pip_fallback() {
    local test_dir
    test_dir="$(mktemp -d)"
    trap 'rm -rf "${test_dir:-}"' RETURN

    setup_repo_workspace "$test_dir"
    local mock_bin="$test_dir/mock_bin"
    local real_py
    real_py="$(command -v python3)"

    mock_sudo "$mock_bin"
    mock_pkg_mgr "$mock_bin" "apt-get" fail-ansible
    create_mock "$mock_bin" "python3" "if [ \"\$1\" = \"-m\" ] && [ \"\$2\" = \"pip\" ]; then
    echo \"PIP_CALLED: \$@\"
    exit 0
fi
exec $real_py \"\$@\""
    mock_make "$mock_bin" false
    link_coreutils "$mock_bin"

    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT" 2>&1)

    if ! echo "$output" | grep -q "PIP_CALLED: -m pip install"; then
        echo "Expected python3 -m pip fallback on Debian/Ubuntu, got: $output" >&2
        return 1
    fi
    return 0
}

test_path_enhancement() {
    local test_dir
    test_dir="$(mktemp -d)"
    trap 'rm -rf "${test_dir:-}"' RETURN

    setup_repo_workspace "$test_dir"
    local mock_bin="$test_dir/mock_bin"

    mock_sudo "$mock_bin"
    mock_pkg_mgr "$mock_bin" "dnf" stub
    mock_ansible_playbook "$mock_bin"
    create_mock "$mock_bin" "make" 'echo "CHECK_PATH:$PATH"
exit 0'
    link_coreutils "$mock_bin"

    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT" 2>&1)

    if ! echo "$output" | grep -q ".local/bin"; then
        echo "Expected PATH to include .local/bin, got: $output" >&2
        return 1
    fi
    return 0
}

test_skip_ansible_when_already_installed() {
    local test_dir
    test_dir="$(mktemp -d)"
    trap 'rm -rf "${test_dir:-}"' RETURN

    setup_repo_workspace "$test_dir"
    local mock_bin="$test_dir/mock_bin"

    mock_sudo "$mock_bin"
    mock_pkg_mgr "$mock_bin" "dnf" log
    mock_make "$mock_bin" false
    mock_ansible_playbook "$mock_bin"
    link_coreutils "$mock_bin"

    local output
    output=$(cd "$test_dir" && PATH="$mock_bin" bash "$BOOTSTRAP_SCRIPT" 2>&1)

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
run_test "Debian/Ubuntu 3-tier fallback to python3 -m pip install" test_apt_pip_fallback
run_test "RPM base package installation" test_rpm_base_packages
run_test "microdnf base package installation with dnf bindings" test_microdnf_base_packages
run_test "RPM 3-tier fallback to python3 -m pip install" test_rpm_pip_fallback
run_test "PATH export and enhancement before make setup" test_path_enhancement
run_test "Skip Ansible installation if already present" test_skip_ansible_when_already_installed

echo "========================================"
echo "All $PASS_COUNT / $TEST_COUNT package tests passed successfully."
