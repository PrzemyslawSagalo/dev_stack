#!/usr/bin/env bats
# shellcheck shell=bash

setup() {
    load "test_helpers.bash"
    test_setup
}

teardown() {
    test_teardown
}

@test "Debian/Ubuntu package installation flow" {
    local test_dir="$BATS_TEST_TMPDIR/apt_flow"
    mkdir -p "$test_dir"

    setup_repo_workspace "$test_dir"
    local mock_bin="$test_dir/mock_bin"

    mock_sudo "$mock_bin"
    mock_pkg_mgr "$mock_bin" "apt-get" log
    mock_make "$mock_bin" false
    mock_ansible_playbook "$mock_bin"
    link_coreutils "$mock_bin"

    run bash -c "cd '$test_dir' && PATH='$mock_bin' bash '$BOOTSTRAP_SCRIPT'"
    assert_success
    assert_output --partial "APT_CALLED: update"
    assert_output --partial "APT_CALLED: install -y git make python3 python3-pip sudo bash"
}

@test "Debian/Ubuntu 3-tier fallback to python3 -m pip install" {
    local test_dir="$BATS_TEST_TMPDIR/apt_pip"
    mkdir -p "$test_dir"

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
exec \"\$real_py\" \"\$@\""
    mock_make "$mock_bin" false
    link_coreutils "$mock_bin"

    run bash -c "cd '$test_dir' && PATH='$mock_bin' bash '$BOOTSTRAP_SCRIPT'"
    assert_success
    assert_output --partial "PIP_CALLED: -m pip install"
}

@test "RPM base package installation" {
    local test_dir="$BATS_TEST_TMPDIR/rpm_base"
    mkdir -p "$test_dir"

    setup_repo_workspace "$test_dir"
    local mock_bin="$test_dir/mock_bin"

    mock_sudo "$mock_bin"
    mock_pkg_mgr "$mock_bin" "dnf" log
    mock_make "$mock_bin" false
    mock_ansible_playbook "$mock_bin"
    link_coreutils "$mock_bin"

    run bash -c "cd '$test_dir' && PATH='$mock_bin' bash '$BOOTSTRAP_SCRIPT'"
    assert_success
    assert_output --partial "DNF_CALLED: install -y git make python3 python3-pip sudo bash"
}

@test "microdnf base package installation with dnf bindings" {
    local test_dir="$BATS_TEST_TMPDIR/microdnf_base"
    mkdir -p "$test_dir"

    setup_repo_workspace "$test_dir"
    local mock_bin="$test_dir/mock_bin"

    mock_sudo "$mock_bin"
    mock_microdnf "$mock_bin"
    mock_make "$mock_bin" false
    mock_ansible_playbook "$mock_bin"
    link_coreutils "$mock_bin"

    run bash -c "cd '$test_dir' && PATH='$mock_bin' bash '$BOOTSTRAP_SCRIPT'"
    assert_success
    assert_output --partial "MICRODNF_CALLED: install -y git make python3 python3-pip dnf python3-dnf sudo bash"
}

@test "RPM 3-tier fallback to python3 -m pip install" {
    local test_dir="$BATS_TEST_TMPDIR/rpm_pip"
    mkdir -p "$test_dir"

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
exec \"\$real_py\" \"\$@\""
    mock_make "$mock_bin" false
    link_coreutils "$mock_bin"

    run bash -c "cd '$test_dir' && PATH='$mock_bin' bash '$BOOTSTRAP_SCRIPT'"
    assert_success
    assert_output --partial "PIP_CALLED: -m pip install"
}

@test "PATH export and enhancement before make setup" {
    local test_dir="$BATS_TEST_TMPDIR/path_enh"
    mkdir -p "$test_dir"

    setup_repo_workspace "$test_dir"
    local mock_bin="$test_dir/mock_bin"

    mock_sudo "$mock_bin"
    mock_pkg_mgr "$mock_bin" "dnf" stub
    mock_ansible_playbook "$mock_bin"
    create_mock "$mock_bin" "make" 'echo "CHECK_PATH:$PATH"
exit 0'
    link_coreutils "$mock_bin"

    run bash -c "cd '$test_dir' && PATH='$mock_bin' bash '$BOOTSTRAP_SCRIPT'"
    assert_success
    assert_output --partial ".local/bin"
}

@test "Skip Ansible installation if already present" {
    local test_dir="$BATS_TEST_TMPDIR/skip_ansible"
    mkdir -p "$test_dir"

    setup_repo_workspace "$test_dir"
    local mock_bin="$test_dir/mock_bin"

    mock_sudo "$mock_bin"
    mock_pkg_mgr "$mock_bin" "dnf" log
    mock_make "$mock_bin" false
    mock_ansible_playbook "$mock_bin"
    link_coreutils "$mock_bin"

    run bash -c "cd '$test_dir' && PATH='$mock_bin' bash '$BOOTSTRAP_SCRIPT'"
    assert_success
    refute_output --partial "Resolving Ansible installation"
    assert_output --partial "ansible-playbook already installed. Skipping installation"
}
