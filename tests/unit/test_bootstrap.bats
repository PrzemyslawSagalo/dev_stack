#!/usr/bin/env bats

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    BOOTSTRAP_SCRIPT="$REPO_DIR/bootstrap.sh"
}

@test "given an os release file that does not exist, when invoking detect_os, then the os id falls back to unknown and the os name to linux" {
    local nonexistent="$BATS_TEST_TMPDIR/nonexistent-os-release"

    run bash -c "
        OS_RELEASE_FILE='$nonexistent'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        detect_os
        echo \"OS_ID=\$OS_ID OS_NAME=\$OS_NAME\"
    "

    assert_success
    assert_output --partial "OS_ID=unknown OS_NAME=Linux"
}

@test "given an unsupported os and no package manager in path, when invoking detect_package_manager, then it fails with an unsupported distribution error" {
    local fixture="$BATS_TEST_TMPDIR/os-release-unknown"
    cat <<'EOF' >"$fixture"
NAME="UnsupportedOS"
ID=unsupported
EOF
    local bin_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$bin_dir"

    run bash -c "
        PATH='$bin_dir'
        OS_RELEASE_FILE='$fixture'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        detect_os
        detect_package_manager
    "

    assert_failure
    assert_output --partial "Unknown package manager or unsupported distribution"
}

@test "given only yum in path, when detecting the package manager, then the distribution is rejected" {
    local bin_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$bin_dir"
    touch "$bin_dir/yum"
    chmod +x "$bin_dir/yum"

    run bash -c "
        PATH='$bin_dir'
        OS_ID=amzn
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        detect_package_manager
    "

    assert_failure
    assert_output --partial "Script supports package managers: apt-get or dnf."
}

@test "given ansible-playbook is installed, when installing ansible, then installation is skipped" {
    local bin_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$bin_dir"
    touch "$bin_dir/ansible-playbook"
    chmod +x "$bin_dir/ansible-playbook"

    run bash -c "
        PATH='$bin_dir'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        install_ansible
    "

    assert_success
    assert_output --partial "ansible-playbook already installed. Skipping installation."
}

@test "given an unsupported os family, when installing ansible, then installation fails" {
    local bin_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$bin_dir"

    run bash -c "
        PATH='$bin_dir'
        OS_FAMILY=unsupported
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        install_ansible
    "

    assert_failure 1
    assert_output --partial "Unsupported OS family 'unsupported' for Ansible installation."
}

@test "given a home directory, when invoking configure_python_path, then the local and system bin directories are prepended to path" {
    local tmp_home="$BATS_TEST_TMPDIR/home"
    mkdir -p "$tmp_home"

    run bash -c "
        HOME='$tmp_home'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        configure_python_path
        echo \"PATH=\$PATH\"
    "

    assert_success
    assert_output --partial "PATH=$tmp_home/.local/bin:/usr/local/bin:"
}

@test "given a shell inside the repository root, when invoking resolve_workspace, then the destination is the repository root without downloading" {
    run bash -c "
        cd '$REPO_DIR'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        resolve_workspace
        echo \"DEST_DIR=\$DEST_DIR\"
    "

    assert_success
    assert_output --partial "DEST_DIR=$REPO_DIR"
}
