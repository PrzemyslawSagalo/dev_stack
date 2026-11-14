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

@test "tj fails cleanly when inside TMUX, when no sessions exist, or when target is invalid" {
    local repo_root
    repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    # Case 1: Inside $TMUX
    run bash -c "
        source '$repo_root/roles/dotfiles/files/bash/.bash_aliases'
        TMUX='dummy-session' tj
    "
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error: already inside a tmux session"* ]]

    # Case 2: No active tmux sessions in isolated socket
    run bash -c "
        unset TMUX
        export TMUX_TMPDIR='$tmp_dir'
        source '$repo_root/roles/dotfiles/files/bash/.bash_aliases'
        tj
    "
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error: no active tmux sessions found"* ]]

    # Case 3: Target session does not exist
    run bash -c "
        unset TMUX
        export TMUX_TMPDIR='$tmp_dir'
        source '$repo_root/roles/dotfiles/files/bash/.bash_aliases'
        tj non_existent_session
    "
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error: tmux session 'non_existent_session' does not exist"* ]]

    # Case 4: Multiple sessions exist without fzf
    unset TMUX
    local bin_dir
    bin_dir="$(mktemp -d)"
    ln -s "$(command -v tmux)" "$bin_dir/tmux"
    ln -s "$(command -v grep)" "$bin_dir/grep"
    TMUX_TMPDIR="$tmp_dir" tmux new-session -d -s sess-alpha
    TMUX_TMPDIR="$tmp_dir" tmux new-session -d -s sess-beta
    run bash -c "
        unset TMUX
        export TMUX_TMPDIR='$tmp_dir'
        source '$repo_root/roles/dotfiles/files/bash/.bash_aliases'
        export PATH='$bin_dir'
        command -v tmux >/dev/null || exit 1
        ! command -v fzf >/dev/null || exit 1
        tj
    "
    TMUX_TMPDIR="$tmp_dir" tmux kill-session -t sess-alpha 2>/dev/null || true
    TMUX_TMPDIR="$tmp_dir" tmux kill-session -t sess-beta 2>/dev/null || true
    rm -rf "$tmp_dir" "$bin_dir"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Error: multiple sessions exist. Specify target session:"* ]]
    [[ "$output" == *"sess-alpha"* ]]
    [[ "$output" == *"sess-beta"* ]]
}

@test "tj creates grouped session sharing window group with destroy-unattached and aggressive-resize" {
    local repo_root
    repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local tmux_conf="$repo_root/roles/dotfiles/files/tmux/.tmux.conf"

    unset TMUX
    TMUX_TMPDIR="$tmp_dir" tmux -f "$tmux_conf" new-session -d -s base-mon-test

    run bash -c "
        unset TMUX
        export TMUX_TMPDIR='$tmp_dir'
        export TERM=xterm-256color

        script -qec \"bash -c 'source \\\"$repo_root/roles/dotfiles/files/bash/.bash_aliases\\\" && tj base-mon-test'\" /dev/null </dev/null >/dev/null 2>&1 &
        CLIENT_PID=\$!

        grouped=''
        for _ in \$(seq 1 30); do
            grouped=\$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep 'base-mon-test-mon-' || true)
            if [ -n \"\$grouped\" ]; then
                break
            fi
            sleep 0.1
        done

        [ -n \"\$grouped\" ]

        base_group=\$(tmux display-message -p -t base-mon-test '#{session_group}')
        grouped_group=\$(tmux display-message -p -t \"\$grouped\" '#{session_group}')
        [ -n \"\$base_group\" ]
        [ \"\$base_group\" = \"\$grouped_group\" ]

        aggressive=\$(tmux show-window-options -g aggressive-resize | awk '{print \$2}')
        [ \"\$aggressive\" = 'on' ]

        destroy_opt=\$(tmux show-options -t \"\$grouped\" destroy-unattached | awk '{print \$2}')
        [ \"\$destroy_opt\" = 'on' ]

        tmux detach-client -s \"\$grouped\" 2>/dev/null || true
        wait \$CLIENT_PID 2>/dev/null || true

        sleep 0.2
        if tmux has-session -t \"\$grouped\" 2>/dev/null; then
            echo 'Error: grouped session was not destroyed on detach'
            exit 1
        fi

        tmux kill-session -t base-mon-test 2>/dev/null || true
    "

    rm -rf "$tmp_dir"
    [ "$status" -eq 0 ]
}

@test "tj automatically selects target session when exactly one tmux session exists" {
    local repo_root
    repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local tmux_conf="$repo_root/roles/dotfiles/files/tmux/.tmux.conf"

    unset TMUX
    TMUX_TMPDIR="$tmp_dir" tmux -f "$tmux_conf" new-session -d -s auto-mon-test

    run bash -c "
        unset TMUX
        export TMUX_TMPDIR='$tmp_dir'
        export TERM=xterm-256color

        script -qec \"bash -c 'source \\\"$repo_root/roles/dotfiles/files/bash/.bash_aliases\\\" && tj'\" /dev/null </dev/null >/dev/null 2>&1 &
        CLIENT_PID=\$!

        grouped=''
        for _ in \$(seq 1 30); do
            grouped=\$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep 'auto-mon-test-mon-' || true)
            if [ -n \"\$grouped\" ]; then
                break
            fi
            sleep 0.1
        done

        [ -n \"\$grouped\" ]

        base_group=\$(tmux display-message -p -t auto-mon-test '#{session_group}')
        grouped_group=\$(tmux display-message -p -t \"\$grouped\" '#{session_group}')
        [ -n \"\$base_group\" ]
        [ \"\$base_group\" = \"\$grouped_group\" ]

        tmux detach-client -s \"\$grouped\" 2>/dev/null || true
        wait \$CLIENT_PID 2>/dev/null || true

        sleep 0.2
        tmux kill-session -t auto-mon-test 2>/dev/null || true
    "

    rm -rf "$tmp_dir"
    [ "$status" -eq 0 ]
}

@test "tj applies aggressive-resize on to session windows even without .tmux.conf" {
    local repo_root
    repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    unset TMUX
    TMUX_TMPDIR="$tmp_dir" tmux -f /dev/null new-session -d -s legacy-mon-test
    TMUX_TMPDIR="$tmp_dir" tmux new-window -t legacy-mon-test

    run bash -c "
        unset TMUX
        export TMUX_TMPDIR='$tmp_dir'
        export TERM=xterm-256color

        script -qec \"bash -c 'source \\\"$repo_root/roles/dotfiles/files/bash/.bash_aliases\\\" && tj legacy-mon-test'\" /dev/null </dev/null >/dev/null 2>&1 &
        CLIENT_PID=\$!

        grouped=''
        for _ in \$(seq 1 30); do
            grouped=\$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep 'legacy-mon-test-mon-' || true)
            if [ -n \"\$grouped\" ]; then
                break
            fi
            sleep 0.1
        done

        [ -n \"\$grouped\" ]

        win_count=0
        while IFS= read -r win_id; do
            [ -n \"\$win_id\" ] || continue
            win_count=\$((win_count + 1))
            opt=\$(tmux show-window-options -t \"\$win_id\" aggressive-resize | awk '{print \$2}')
            [ \"\$opt\" = 'on' ] || exit 1
        done < <(tmux list-windows -t \"\$grouped\" -F '#{window_id}')
        [ \"\$win_count\" -eq 2 ]

        tmux detach-client -s \"\$grouped\" 2>/dev/null || true
        wait \$CLIENT_PID 2>/dev/null || true

        sleep 0.2
        tmux kill-session -t legacy-mon-test 2>/dev/null || true
    "

    rm -rf "$tmp_dir"
    [ "$status" -eq 0 ]
}
