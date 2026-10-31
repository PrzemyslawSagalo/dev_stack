#!/usr/bin/env bats
# shellcheck shell=bash

setup() {
    load "test_helpers.bash"
    test_setup
}

teardown() {
    test_teardown
}

@test "Bash syntax verification" {
    run bash -n "$BOOTSTRAP_SCRIPT"
    assert_success
    run sh -n "$BOOTSTRAP_SCRIPT"
    assert_success
    run bash -n "$REPO_ROOT/tests/test_helpers.bash"
    assert_success
}

@test "In-repo workspace detection via script directory" {
    local test_dir="$BATS_TEST_TMPDIR/external_run"
    mkdir -p "$test_dir"

    local mock_bin="$test_dir/mock_bin"
    mock_pkg_mgr "$mock_bin" "apt-get"
    mock_pkg_mgr "$mock_bin" "dnf"
    mock_sudo "$mock_bin"
    create_mock "$mock_bin" "git" 'echo "GIT_CALLED"; exit 0'
    mock_make "$mock_bin" true

    run bash -c "cd '$test_dir' && PATH='$mock_bin:$PATH' bash '$BOOTSTRAP_SCRIPT'"
    assert_success
    assert_output --partial "MAKE_PWD=$REPO_ROOT"
    refute_output --partial "GIT_CALLED"
}

@test "In-repo workspace detection via piped stdin (curl | bash)" {
    local test_dir="$BATS_TEST_TMPDIR/repo_workspace"
    mkdir -p "$test_dir"

    setup_repo_workspace "$test_dir"
    local mock_bin="$test_dir/mock_bin"
    mock_pkg_mgr "$mock_bin" "apt-get"
    mock_pkg_mgr "$mock_bin" "dnf"
    mock_sudo "$mock_bin"
    create_mock "$mock_bin" "git" 'echo "GIT_CALLED"; exit 0'
    mock_make "$mock_bin" true

    run bash -c "cd '$test_dir' && PATH='$mock_bin:$PATH' bash < '$BOOTSTRAP_SCRIPT'"
    assert_success
    assert_output --partial "MAKE_PWD=$test_dir"
    refute_output --partial "GIT_CALLED"
}

@test "Unvalidated directory with setup.yml is not hijacked" {
    local test_dir="$BATS_TEST_TMPDIR/unvalidated"
    mkdir -p "$test_dir"

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

    run bash -c "cd '$test_dir' && HOME='$mock_home' PATH='$mock_bin:$PATH' bash < '$BOOTSTRAP_SCRIPT'"
    assert_success
    assert_output --partial "CLONING_REPO"
    assert_output --partial "MAKE_PWD=$mock_home/.dev_env"
}

@test "Corrupted or non-git destination directory is cleaned and re-cloned" {
    local test_dir="$BATS_TEST_TMPDIR/corrupt_git"
    mkdir -p "$test_dir"

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

    run bash -c "cd '$test_dir' && HOME='$mock_home' PATH='$mock_bin:$PATH' bash < '$BOOTSTRAP_SCRIPT'"
    assert_success
    assert_output --partial "CLONE_CALLED"
    assert_output --partial "MAKE_PWD=$mock_home/.dev_env"
}

@test "Standalone workspace cloning when setup.yml is missing" {
    local test_dir="$BATS_TEST_TMPDIR/standalone"
    mkdir -p "$test_dir"

    local mock_home="$test_dir/fake_home"
    mkdir -p "$mock_home"
    local mock_bin="$test_dir/mock_bin"

    mock_pkg_mgr "$mock_bin" "apt-get"
    mock_pkg_mgr "$mock_bin" "dnf"
    mock_sudo "$mock_bin"
    create_mock "$mock_bin" "git" 'if [ "$1" = "clone" ]; then mkdir -p "$3"; fi; exit 0'
    mock_make "$mock_bin" true

    local expected_dest="$mock_home/.dev_env"

    run bash -c "cd '$test_dir' && HOME='$mock_home' PATH='$mock_bin:$PATH' bash < '$BOOTSTRAP_SCRIPT'"
    assert_success
    assert_output --partial "MAKE_PWD=$expected_dest"
}

@test "Privilege escalation error check (non-root without sudo)" {
    local test_dir="$BATS_TEST_TMPDIR/priv_check"
    mkdir -p "$test_dir"

    local mock_bin="$test_dir/mock_bin"
    local real_id
    real_id="$(command -v id)"
    create_mock "$mock_bin" "id" "if [ \"\$1\" = \"-u\" ]; then
    echo \"1000\"
else
    \"\$real_id\" \"\$@\"
fi"
    link_coreutils "$mock_bin"

    run bash -c "cd '$test_dir' && PATH='$mock_bin' bash '$BOOTSTRAP_SCRIPT'"
    assert_failure 1
    assert_output --regexp "sudo.*not found|install sudo|run.*root"
}

@test "Microdnf package manager detection on minimal UBI" {
    local test_dir="$BATS_TEST_TMPDIR/microdnf_check"
    mkdir -p "$test_dir"

    touch "$test_dir/setup.yml"
    local mock_bin="$test_dir/mock_bin"

    mock_sudo "$mock_bin"
    mock_microdnf "$mock_bin"
    mock_make "$mock_bin" false
    mock_ansible_playbook "$mock_bin"
    link_coreutils "$mock_bin"

    run bash -c "cd '$test_dir' && PATH='$mock_bin' bash '$BOOTSTRAP_SCRIPT'"
    assert_success
    assert_output --partial "MICRODNF_CALLED: install -y git make python3 python3-pip dnf python3-dnf sudo"
}
