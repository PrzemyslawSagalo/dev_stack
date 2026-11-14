#!/usr/bin/env bats

setup() {
    if [ -f "$HOME/.profile" ]; then
        # shellcheck disable=SC1090,SC1091
        source "$HOME/.profile" 2>/dev/null || true
    fi
}

@test "git check-ignore honors global gitignore rules for secret files" {
    local tmp_repo
    tmp_repo="$(mktemp -d)"
    git init "$tmp_repo" >/dev/null 2>&1
    touch "$tmp_repo/.envrc" "$tmp_repo/.envrc.local" "$tmp_repo/.env" "$tmp_repo/.env.local" "$tmp_repo/.env.example" "$tmp_repo/.env.template"

    run git -C "$tmp_repo" check-ignore .envrc .envrc.local .env .env.local
    [ "$status" -eq 0 ]
    [[ "$output" == *".envrc"* ]]
    [[ "$output" == *".envrc.local"* ]]
    [[ "$output" == *".env"* ]]
    [[ "$output" == *".env.local"* ]]

    run git -C "$tmp_repo" check-ignore .env.example .env.template
    [ "$status" -ne 0 ]

    rm -rf "$tmp_repo"
}

@test "yq evaluates YAML queries and extracts document fields" {
    local repo_root
    repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
    run yq '.[0].name' "$repo_root/setup.yml"
    [ "$status" -eq 0 ]
    [ "$output" = "Setup Development Environment" ]
}

@test "direnv evaluates allowed .envrc and exports environment variables" {
    local test_dir
    test_dir="$(mktemp -d)"
    echo 'export E2E_TEST_DIRENV_VAR="direnv_e2e_ok"' >"$test_dir/.envrc"

    run bash -c "
        cd '$test_dir'
        direnv allow '$test_dir/.envrc'
        eval \"\$(direnv export bash 2>/dev/null)\"
        [ \"\$E2E_TEST_DIRENV_VAR\" = 'direnv_e2e_ok' ]
    "
    rm -rf "$test_dir"
    [ "$status" -eq 0 ]
}

@test "resolve_workspace downloads, verifies, and extracts release package when executed outside workspace" {
    local repo_root
    repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local tmp_release_dir="$tmp_dir/release"
    local run_dir="$tmp_dir/run"
    mkdir -p "$tmp_release_dir" "$run_dir"

    git -C "$repo_root" archive --format=tar.gz -o "$tmp_release_dir/dev_stack.tar.gz" HEAD
    (cd "$tmp_release_dir" && sha256sum dev_stack.tar.gz >dev_stack.tar.gz.sha256)

    run bash -c "
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
        rm -rf \"\$DEST_DIR\"
    "
    local extracted_dest
    extracted_dest="$(echo "$output" | grep -o 'workspace ([^)]*)' | sed 's/workspace (//; s/)//')"
    if [ -n "$extracted_dest" ] && [ -d "$extracted_dest" ]; then
        rm -rf "$extracted_dest"
    fi
    rm -rf "$tmp_dir"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DEST_DIR=/tmp/"* ]]
    [[ "$output" == *"CLEANUP_DEST_DIR=1"* ]]
}

@test "resolve_workspace fails when release package checksum does not match" {
    local repo_root
    repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local tmp_release_dir="$tmp_dir/release"
    local run_dir="$tmp_dir/run"
    mkdir -p "$tmp_release_dir" "$run_dir"

    echo "invalid archive payload" >"$tmp_release_dir/dev_stack.tar.gz"
    echo "0000000000000000000000000000000000000000000000000000000000000000  dev_stack.tar.gz" >"$tmp_release_dir/dev_stack.tar.gz.sha256"

    run bash -c "
        cd '$run_dir'
        RELEASE_BASE_URL='file://$tmp_release_dir'
        BOOTSTRAP_SOURCE_ONLY=1 . '$repo_root/bootstrap.sh'
        resolve_workspace
    "
    local extracted_dest
    extracted_dest="$(echo "$output" | grep -o 'workspace ([^)]*)' | sed 's/workspace (//; s/)//')"
    if [ -n "$extracted_dest" ] && [ -d "$extracted_dest" ]; then
        rm -rf "$extracted_dest"
    fi
    rm -rf "$tmp_dir"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Failed to download or verify release package"* ]]
}
