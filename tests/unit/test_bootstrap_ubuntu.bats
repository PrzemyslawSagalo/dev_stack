#!/usr/bin/env bats

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    BOOTSTRAP_SCRIPT="$REPO_DIR/bootstrap.sh"
    OS_RELEASE_FIXTURE="$BATS_TEST_TMPDIR/os-release"
    cat <<'EOF' >"$OS_RELEASE_FIXTURE"
NAME="Ubuntu"
ID=ubuntu
ID_LIKE=debian
EOF
}

@test "given an Ubuntu os-release, when invoking detect_os, then OS_ID, OS_NAME, and OS_ID_LIKE reflect Ubuntu" {
    run bash -c "
        OS_RELEASE_FILE='$OS_RELEASE_FIXTURE'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        detect_os
        echo \"OS_ID=\$OS_ID OS_NAME=\$OS_NAME OS_ID_LIKE=\$OS_ID_LIKE\"
    "

    assert_success
    assert_output --partial "OS_ID=ubuntu OS_NAME=Ubuntu OS_ID_LIKE=debian"
}

@test "given Ubuntu and apt-get in PATH, when invoking detect_package_manager, then OS_FAMILY is debian and PKG_MGR is apt-get" {
    local bin_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$bin_dir"
    touch "$bin_dir/apt-get"
    chmod +x "$bin_dir/apt-get"

    run bash -c "
        PATH='$bin_dir'
        OS_RELEASE_FILE='$OS_RELEASE_FIXTURE'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        detect_os
        detect_package_manager
        echo \"FAMILY=\$OS_FAMILY MGR=\$PKG_MGR\"
    "

    assert_success
    assert_output --partial "FAMILY=debian MGR=apt-get"
}
