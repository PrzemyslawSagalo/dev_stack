#!/usr/bin/env bats

setup() {
    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    BOOTSTRAP_SCRIPT="$REPO_DIR/bootstrap.sh"
    TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    if [ -n "${TEST_TMPDIR:-}" ] && [ -d "$TEST_TMPDIR" ]; then
        rm -rf "$TEST_TMPDIR"
    fi
}

@test "detect_os parses Ubuntu os-release fixture" {
    local fixture="$TEST_TMPDIR/os-release-ubuntu"
    cat <<'EOF' >"$fixture"
NAME="Ubuntu"
ID=ubuntu
ID_LIKE=debian
EOF

    run bash -c "
        OS_RELEASE_FILE='$fixture'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        detect_os
        echo \"OS_ID=\$OS_ID OS_NAME=\$OS_NAME OS_ID_LIKE=\$OS_ID_LIKE\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "OS_ID=ubuntu OS_NAME=Ubuntu OS_ID_LIKE=debian" ]]
}

@test "detect_os parses Amazon Linux os-release fixture" {
    local fixture="$TEST_TMPDIR/os-release-amzn"
    cat <<'EOF' >"$fixture"
NAME="Amazon Linux"
ID="amzn"
ID_LIKE="fedora"
EOF

    run bash -c "
        OS_RELEASE_FILE='$fixture'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        detect_os
        echo \"OS_ID=\$OS_ID OS_NAME=\$OS_NAME OS_ID_LIKE=\$OS_ID_LIKE\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "OS_ID=amzn OS_NAME=Amazon Linux OS_ID_LIKE=fedora" ]]
}

@test "detect_os falls back to unknown and Linux when OS_RELEASE_FILE does not exist" {
    local nonexistent="$TEST_TMPDIR/nonexistent-os-release"

    run bash -c "
        OS_RELEASE_FILE='$nonexistent'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        detect_os
        echo \"OS_ID=\$OS_ID OS_NAME=\$OS_NAME\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "OS_ID=unknown OS_NAME=Linux" ]]
}

@test "detect_package_manager selects debian and apt-get for Ubuntu fixture" {
    local fixture="$TEST_TMPDIR/os-release-ubuntu"
    cat <<'EOF' >"$fixture"
NAME="Ubuntu"
ID=ubuntu
ID_LIKE=debian
EOF
    local bin_dir="$TEST_TMPDIR/bin"
    mkdir -p "$bin_dir"
    touch "$bin_dir/apt-get"
    chmod +x "$bin_dir/apt-get"

    run bash -c "
        PATH='$bin_dir'
        OS_RELEASE_FILE='$fixture'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        detect_os
        detect_package_manager
        echo \"FAMILY=\$OS_FAMILY MGR=\$PKG_MGR\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "FAMILY=debian MGR=apt-get" ]]
}

@test "detect_package_manager selects amazon and dnf for Amazon Linux fixture" {
    local fixture="$TEST_TMPDIR/os-release-amzn"
    cat <<'EOF' >"$fixture"
NAME="Amazon Linux"
ID="amzn"
ID_LIKE="fedora"
EOF
    local bin_dir="$TEST_TMPDIR/bin"
    mkdir -p "$bin_dir"
    touch "$bin_dir/dnf"
    chmod +x "$bin_dir/dnf"

    run bash -c "
        PATH='$bin_dir'
        OS_RELEASE_FILE='$fixture'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        detect_os
        detect_package_manager
        echo \"FAMILY=\$OS_FAMILY MGR=\$PKG_MGR\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "FAMILY=amazon MGR=dnf" ]]
}

@test "detect_package_manager exits non-zero with clear error for unsupported OS when no supported package manager is in PATH" {
    local fixture="$TEST_TMPDIR/os-release-unknown"
    cat <<'EOF' >"$fixture"
NAME="UnsupportedOS"
ID=unsupported
EOF
    local bin_dir="$TEST_TMPDIR/bin"
    mkdir -p "$bin_dir"

    run bash -c "
        PATH='$bin_dir'
        OS_RELEASE_FILE='$fixture'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        detect_os
        detect_package_manager
    "
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Unknown package manager or unsupported distribution" ]]
}

@test "configure_python_path prepends HOME local bin and usr local bin to PATH" {
    local tmp_home="$TEST_TMPDIR/home"
    mkdir -p "$tmp_home"

    run bash -c "
        HOME='$tmp_home'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        configure_python_path
        echo \"PATH=\$PATH\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"PATH=$tmp_home/.local/bin:/usr/local/bin:"* ]]
}

@test "resolve_workspace detects existing repository workspace" {
    run bash -c "
        cd '$REPO_DIR'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        resolve_workspace
        echo \"DEST_DIR=\$DEST_DIR\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"DEST_DIR=$REPO_DIR"* ]]
}
