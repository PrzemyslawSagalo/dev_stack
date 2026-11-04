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
    command -v git >/dev/null 2>&1
    command -v make >/dev/null 2>&1
    command -v python3 >/dev/null 2>&1
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
    run bash -c "
        cd '$REPO_DIR'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        resolve_workspace
        echo \"DEST_DIR=\$DEST_DIR\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"DEST_DIR=$REPO_DIR"* ]]
}

@test "resolve_workspace clones repository when executed outside workspace" {
    local tmp_user_home
    tmp_user_home="$(mktemp -d)"
    run bash -c "
        cd /tmp
        HOME='$tmp_user_home'
        BOOTSTRAP_SOURCE_ONLY=1 . '$BOOTSTRAP_SCRIPT'
        resolve_workspace
        echo \"DEST_DIR=\$DEST_DIR\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"DEST_DIR=$tmp_user_home/.dev_stack"* ]]
    [ -d "$tmp_user_home/.dev_stack/.git" ]
    rm -rf "$tmp_user_home"
}
