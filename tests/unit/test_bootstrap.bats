#!/usr/bin/env bats

setup() {
    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    BOOTSTRAP_SCRIPT="$REPO_DIR/bootstrap.sh"
}

@test "verify_sudo_access sets sudo command for non-root user" {
    run bash -c "BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'; verify_sudo_access; echo \"SUDO=\$SUDO\""
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SUDO=sudo" ]]
}

@test "verify_sudo_access sets empty sudo for root user" {
    run sudo bash -c "BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'; verify_sudo_access; echo \"SUDO=\$SUDO\""
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SUDO=" ]]
    [[ ! "$output" =~ "SUDO=sudo" ]]
}

@test "detect_os parses distribution from os-release" {
    run bash -c "BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'; detect_os; echo \"OS_ID=\$OS_ID OS_NAME=\$OS_NAME\""
    [ "$status" -eq 0 ]
    [[ "$output" =~ OS_ID=(ubuntu|amzn) ]]
}

@test "detect_package_manager selects package manager for distribution" {
    run bash -c "BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'; detect_os; detect_package_manager; echo \"FAMILY=\$OS_FAMILY MGR=\$PKG_MGR\""
    [ "$status" -eq 0 ]
    if grep -q "ID=ubuntu" /etc/os-release; then
        [[ "$output" =~ "FAMILY=debian MGR=apt-get" ]]
    else
        [[ "$output" =~ "FAMILY=amazon MGR=dnf" ]]
    fi
}

@test "install_base_dependencies installs base packages on system" {
    run bash -c "
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        verify_sudo_access
        detect_os
        detect_package_manager
        install_base_dependencies
    "
    [ "$status" -eq 0 ]
    command -v python3 >/dev/null 2>&1
    command -v curl >/dev/null 2>&1
    command -v tar >/dev/null 2>&1
    command -v gzip >/dev/null 2>&1
}

@test "install_ansible installs ansible-playbook on system" {
    run bash -c "
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        verify_sudo_access
        detect_os
        detect_package_manager
        install_ansible
    "
    [ "$status" -eq 0 ]
    command -v ansible-playbook >/dev/null 2>&1
}

@test "install_ansible skips installation when ansible-playbook is already present" {
    run bash -c "
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        install_ansible
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"ansible-playbook already installed. Skipping installation."* ]]
}

@test "configure_python_path prepends local bin directories to PATH" {
    run bash -c "
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        configure_python_path
        echo \"PATH=\$PATH\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"$HOME/.local/bin"* ]]
}

@test "resolve_workspace detects existing repository workspace" {
    local tmp_user_home
    tmp_user_home="$(mktemp -d)"
    run bash -c "
        cd '$REPO_DIR'
        HOME='$tmp_user_home'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        resolve_workspace
        echo \"DEST_DIR=\$DEST_DIR\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"DEST_DIR=$REPO_DIR"* ]]
    rm -rf "$tmp_user_home"
}

@test "resolve_workspace downloads, verifies, and extracts release package when executed outside workspace" {
    local tmp_user_home tmp_release_dir
    tmp_user_home="$(mktemp -d)"
    tmp_release_dir="$(mktemp -d)"

    git -C "$REPO_DIR" archive --format=tar.gz -9 -o "$tmp_release_dir/dev_stack.tar.gz" HEAD
    (cd "$tmp_release_dir" && sha256sum dev_stack.tar.gz >dev_stack.tar.gz.sha256)

    run bash -c "
        cd /tmp
        HOME='$tmp_user_home'
        RELEASE_BASE_URL='file://$tmp_release_dir'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        configure_python_path
        resolve_workspace
        echo \"DEST_DIR=\$DEST_DIR\"
        echo \"CLEANUP_DEST_DIR=\$CLEANUP_DEST_DIR\"
        [ -f \"\$DEST_DIR/setup.yml\" ]
        [ -d \"\$DEST_DIR/roles/system\" ]
        [ ! -d \"\$DEST_DIR/.git\" ]
        [ ! -d \"\$DEST_DIR/tests\" ]
        [ ! -d \"\$DEST_DIR/.github\" ]
        [ \"\$CLEANUP_DEST_DIR\" = \"1\" ]
        rm -rf \"\$DEST_DIR\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"DEST_DIR=/tmp/"* ]]
    [[ "$output" == *"CLEANUP_DEST_DIR=1"* ]]
    rm -rf "$tmp_user_home" "$tmp_release_dir"
}

@test "resolve_workspace fails when release package checksum does not match" {
    local tmp_user_home tmp_release_dir
    tmp_user_home="$(mktemp -d)"
    tmp_release_dir="$(mktemp -d)"

    git -C "$REPO_DIR" archive --format=tar.gz -9 -o "$tmp_release_dir/dev_stack.tar.gz" HEAD
    echo "0000000000000000000000000000000000000000000000000000000000000000  dev_stack.tar.gz" >"$tmp_release_dir/dev_stack.tar.gz.sha256"

    run bash -c "
        cd /tmp
        HOME='$tmp_user_home'
        RELEASE_BASE_URL='file://$tmp_release_dir'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        configure_python_path
        resolve_workspace
    "
    [ "$status" -ne 0 ]
    rm -rf "$tmp_user_home" "$tmp_release_dir"
}

@test "system multi-arch metadata resolves correctly for x86_64 architecture" {
    run bash -c "
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        configure_python_path
        ansible localhost -i localhost, -c local \
            -e 'ansible_architecture=x86_64' \
            -e '@$REPO_DIR/roles/system/defaults/main.yml' \
            -m ansible.builtin.debug -a 'var=system_default_pkg_metadata'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"awscli-exe-linux-x86_64.zip"* ]]
    [[ "$output" == *"copilot-linux-x64-"* ]]
    [[ "$output" == *"docker-compose-linux-x86_64"* ]]
    [[ "$output" == *"linux-amd64.tar.gz"* ]]
    [[ "$output" == *"linux_x86_64.tar.gz"* ]]
    [[ "$output" == *"openshift-client-linux.tar.gz"* ]]
    [[ "$output" == *"-x86_64-unknown-linux-musl.tar.gz"* ]]
    [[ "$output" == *"tree-sitter-linux-x64.gz"* ]]
}

@test "system multi-arch metadata resolves correctly for aarch64 architecture" {
    run bash -c "
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        configure_python_path
        ansible localhost -i localhost, -c local \
            -e 'ansible_architecture=aarch64' \
            -e '@$REPO_DIR/roles/system/defaults/main.yml' \
            -m ansible.builtin.debug -a 'var=system_default_pkg_metadata'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"awscli-exe-linux-aarch64.zip"* ]]
    [[ "$output" == *"copilot-linux-arm64-"* ]]
    [[ "$output" == *"docker-compose-linux-aarch64"* ]]
    [[ "$output" == *"linux-arm64.tar.gz"* ]]
    [[ "$output" == *"linux_arm64.tar.gz"* ]]
    [[ "$output" == *"openshift-client-linux-arm64.tar.gz"* ]]
    [[ "$output" == *"-aarch64-unknown-linux-gnu.tar.gz"* ]]
    [[ "$output" == *"tree-sitter-linux-arm64.gz"* ]]
}
