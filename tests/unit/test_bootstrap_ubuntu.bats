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

@test "given an ubuntu os release, when invoking detect_os, then the os id, name, and id like reflect ubuntu" {
    run bash -c "
        OS_RELEASE_FILE='$OS_RELEASE_FIXTURE'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        detect_os
        echo \"OS_ID=\$OS_ID OS_NAME=\$OS_NAME OS_ID_LIKE=\$OS_ID_LIKE\"
    "

    assert_success
    assert_output --partial "OS_ID=ubuntu OS_NAME=Ubuntu OS_ID_LIKE=debian"
}

@test "given ubuntu and apt-get in path, when invoking detect_package_manager, then the os family is debian and the package manager is apt-get" {
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

@test "given debian and unset sudo, when installing ansible, then apt-get installs ansible noninteractively" {
    local bin_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$bin_dir"
    ln -s /usr/bin/env "$bin_dir/env"
    cat <<'EOF' >"$bin_dir/apt-get"
#!/bin/bash
printf '%s %s\n' "$DEBIAN_FRONTEND" "$*"
EOF
    chmod +x "$bin_dir/apt-get"

    run bash -c "
        PATH='$bin_dir'
        unset SUDO
        OS_FAMILY=debian
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        install_ansible
    "

    assert_success
    assert_output "noninteractive install -y ansible"
}

@test "given debian and sudo, when installing ansible, then apt-get runs through sudo" {
    local bin_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$bin_dir"
    cat <<'EOF' >"$bin_dir/sudo"
#!/bin/bash
printf '%s\n' "$*"
EOF
    chmod +x "$bin_dir/sudo"

    run bash -c "
        PATH='$bin_dir'
        SUDO=sudo
        OS_FAMILY=debian
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        install_ansible
    "

    assert_success
    assert_output "env DEBIAN_FRONTEND=noninteractive apt-get install -y ansible"
}
