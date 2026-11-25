#!/usr/bin/env bats

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    BOOTSTRAP_SCRIPT="$REPO_DIR/bootstrap.sh"
    OS_RELEASE_FIXTURE="$BATS_TEST_TMPDIR/os-release"
    cat <<'EOF' >"$OS_RELEASE_FIXTURE"
NAME="Amazon Linux"
ID="amzn"
ID_LIKE="fedora"
EOF
}

@test "detect_os parses Amazon Linux os-release fixture" {
    run bash -c "
        OS_RELEASE_FILE='$OS_RELEASE_FIXTURE'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        detect_os
        echo \"OS_ID=\$OS_ID OS_NAME=\$OS_NAME OS_ID_LIKE=\$OS_ID_LIKE\"
    "
    assert_success
    assert_output --partial "OS_ID=amzn OS_NAME=Amazon Linux OS_ID_LIKE=fedora"
}

@test "detect_package_manager selects amazon and dnf for Amazon Linux fixture" {
    local bin_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$bin_dir"
    touch "$bin_dir/dnf"
    chmod +x "$bin_dir/dnf"

    run bash -c "
        PATH='$bin_dir'
        OS_RELEASE_FILE='$OS_RELEASE_FIXTURE'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        detect_os
        detect_package_manager
        echo \"FAMILY=\$OS_FAMILY MGR=\$PKG_MGR\"
    "
    assert_success
    assert_output --partial "FAMILY=amazon MGR=dnf"
}
