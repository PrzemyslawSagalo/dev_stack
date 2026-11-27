#!/usr/bin/env bats

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    if [ -f "$HOME/.profile" ]; then
        # shellcheck disable=SC1090,SC1091
        source "$HOME/.profile" 2>/dev/null || true
    fi
}

@test "given a git repository with secret and template env files, when running git check-ignore, then secrets are ignored and templates stay tracked" {
    local tmp_repo="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$tmp_repo"
    git init "$tmp_repo" >/dev/null 2>&1
    touch "$tmp_repo/.envrc" "$tmp_repo/.envrc.local" "$tmp_repo/.env" "$tmp_repo/.env.local" "$tmp_repo/.env.example" "$tmp_repo/.env.template"

    run git -C "$tmp_repo" check-ignore .envrc .envrc.local .env .env.local

    assert_success
    assert_output --partial ".envrc"
    assert_output --partial ".envrc.local"
    assert_output --partial ".env"
    assert_output --partial ".env.local"

    run git -C "$tmp_repo" check-ignore .env.example .env.template
    assert_failure
}

@test "given the setup.yml playbook, when evaluating .[0].name with yq, then the play name is returned" {
    local repo_root
    repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"

    run yq '.[0].name' "$repo_root/setup.yml"

    assert_success
    assert_output "Setup Development Environment"
}

@test "given an allowed .envrc exporting a variable, when evaluating direnv export bash, then the variable is exported" {
    local test_dir="$BATS_TEST_TMPDIR/direnv"
    mkdir -p "$test_dir"
    echo 'export E2E_TEST_DIRENV_VAR="direnv_e2e_ok"' >"$test_dir/.envrc"

    run bash -c "
        cd '$test_dir'
        direnv allow '$test_dir/.envrc'
        eval \"\$(direnv export bash 2>/dev/null)\"
        [ \"\$E2E_TEST_DIRENV_VAR\" = 'direnv_e2e_ok' ]
    "

    assert_success
}

@test "given a release tarball with matching checksum and an outside directory, when invoking resolve_workspace, then the archive is extracted into a temporary DEST_DIR marked for cleanup" {
    local repo_root
    repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
    local tmp_release_dir="$BATS_TEST_TMPDIR/release"
    local run_dir="$BATS_TEST_TMPDIR/run"
    mkdir -p "$tmp_release_dir" "$run_dir"

    git -C "$repo_root" archive --format=tar.gz -o "$tmp_release_dir/dev_stack.tar.gz" HEAD
    (cd "$tmp_release_dir" && sha256sum dev_stack.tar.gz >dev_stack.tar.gz.sha256)

    run env TMPDIR="$BATS_TEST_TMPDIR" bash -c "
        cd '$run_dir'
        RELEASE_BASE_URL='file://$tmp_release_dir'
        BOOTSTRAP_SOURCE_ONLY=1 . '$repo_root/bootstrap.sh'
        resolve_workspace
        echo \"DEST_DIR=\$DEST_DIR\"
        echo \"CLEANUP_DEST_DIR=\$CLEANUP_DEST_DIR\"
        [ -f \"\$DEST_DIR/setup.yml\" ]
        [ -d \"\$DEST_DIR/roles/system\" ]
        [ ! -d \"\$DEST_DIR/.git\" ]
        [ \"\$CLEANUP_DEST_DIR\" = \"1\" ]
    "

    assert_success
    assert_output --partial "DEST_DIR=$BATS_TEST_TMPDIR/"
    assert_output --partial "CLEANUP_DEST_DIR=1"
}

@test "given a release tarball with a mismatched checksum, when invoking resolve_workspace, then it fails with a download verification error" {
    local repo_root
    repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
    local tmp_release_dir="$BATS_TEST_TMPDIR/release"
    local run_dir="$BATS_TEST_TMPDIR/run"
    mkdir -p "$tmp_release_dir" "$run_dir"

    echo "invalid archive payload" >"$tmp_release_dir/dev_stack.tar.gz"
    echo "0000000000000000000000000000000000000000000000000000000000000000  dev_stack.tar.gz" >"$tmp_release_dir/dev_stack.tar.gz.sha256"

    run env TMPDIR="$BATS_TEST_TMPDIR" bash -c "
        cd '$run_dir'
        RELEASE_BASE_URL='file://$tmp_release_dir'
        BOOTSTRAP_SOURCE_ONLY=1 . '$repo_root/bootstrap.sh'
        resolve_workspace
    "

    assert_failure
    assert_output --partial "Failed to download or verify release package"
}

@test "given the dev_stack manual is installed, when rendering it with man, then the requested section headings are present" {
    run env MANPAGER=cat man dev_stack

    assert_success
    assert_output --partial "NAME"
    assert_output --partial "SHELL ALIASES"
    assert_output --partial "TMUX"
    assert_output --partial "NEOVIM"
    assert_output --partial "CONFIGURATION FILES"
}

@test "given the repository dev_stack manual, when checking groff diagnostics, then no warnings or errors are emitted" {
    local repo_root
    repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"

    run groff -man -Tutf8 -ww -z "$repo_root/roles/system/files/man/dev_stack.7"

    assert_success
    assert_output ""
}
