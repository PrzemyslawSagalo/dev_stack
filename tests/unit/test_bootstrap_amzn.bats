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

@test "given an amazon linux os release, when invoking detect_os, then the os id, name, and id like reflect amazon linux" {
    run bash -c "
        OS_RELEASE_FILE='$OS_RELEASE_FIXTURE'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        detect_os
        echo \"OS_ID=\$OS_ID OS_NAME=\$OS_NAME OS_ID_LIKE=\$OS_ID_LIKE\"
    "

    assert_success
    assert_output --partial "OS_ID=amzn OS_NAME=Amazon Linux OS_ID_LIKE=fedora"
}

@test "given amazon linux and dnf in path, when invoking detect_package_manager, then the os family is amazon and the package manager is dnf" {
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

@test "given amazon linux and no ansible-playbook in path, when installing ansible, then pip installs ansible-core for the user" {
    local bin_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$bin_dir"
    cat <<'EOF' >"$bin_dir/python3"
#!/bin/bash
printf '%s\n' "$*"
EOF
    chmod +x "$bin_dir/python3"

    run bash -c "
        PATH='$bin_dir'
        OS_FAMILY=amazon
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        install_ansible
    "

    assert_success
    assert_output "-m pip install --user --no-cache-dir ansible-core"
}
