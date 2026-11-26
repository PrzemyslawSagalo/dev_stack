#!/usr/bin/env bats

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    BOOTSTRAP_SCRIPT="$REPO_DIR/bootstrap.sh"
}

@test "given an OS_RELEASE_FILE that does not exist, when invoking detect_os, then OS_ID falls back to unknown and OS_NAME to Linux" {
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

@test "given an unsupported OS and no package manager in PATH, when invoking detect_package_manager, then it fails with an unsupported distribution error" {
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

@test "given a HOME directory, when invoking configure_python_path, then HOME/.local/bin and /usr/local/bin are prepended to PATH" {
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

@test "given a shell inside the repository root, when invoking resolve_workspace, then DEST_DIR is the repository root without downloading" {
    run bash -c "
        cd '$REPO_DIR'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        resolve_workspace
        echo \"DEST_DIR=\$DEST_DIR\"
    "

    assert_success
    assert_output --partial "DEST_DIR=$REPO_DIR"
}
