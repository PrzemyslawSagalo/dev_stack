#!/usr/bin/env bats

setup() {
    if [ -f "$HOME/.profile" ]; then
        # shellcheck disable=SC1090,SC1091
        source "$HOME/.profile" 2>/dev/null || true
    fi
}

_init_gsquash_repo() {
    local repo_dir="$1"
    local init_file="${2:-base.txt}"
    local init_content="${3:-Base line}"
    local init_msg="${4:-chore: base commit}"

    git init "$repo_dir" >/dev/null 2>&1
    git -C "$repo_dir" config user.name "Test User"
    git -C "$repo_dir" config user.email "test@example.com"
    echo "$init_content" >"$repo_dir/$init_file"
    git -C "$repo_dir" add "$init_file"
    git -C "$repo_dir" commit -m "$init_msg" >/dev/null 2>&1
}

_run_gsquash() {
    local target_dir="$1"
    shift
    local repo_root
    repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
    (
        # shellcheck disable=SC1090,SC1091
        source "$repo_root/roles/dotfiles/files/bash/.bash_aliases"
        cd "$target_dir" || exit 1
        gsquash "$@"
    )
}

@test "gsquash collapses subsequent wip commits into target commit preserving its message and all file changes" {
    local tmp_repo="$BATS_TEST_TMPDIR/repo"

    _init_gsquash_repo "$tmp_repo" "file1.txt" "Initial line" "feat(core): initial target commit"
    local target_hash
    target_hash="$(git -C "$tmp_repo" rev-parse HEAD)"

    echo "WIP edit 1" >>"$tmp_repo/file1.txt"
    echo "File 2 content" >"$tmp_repo/file2.txt"
    git -C "$tmp_repo" add file1.txt file2.txt
    git -C "$tmp_repo" commit -m "wip: first batch" >/dev/null 2>&1

    echo "WIP edit 2" >>"$tmp_repo/file1.txt"
    echo "File 3 content" >"$tmp_repo/file3.txt"
    git -C "$tmp_repo" add file1.txt file3.txt
    git -C "$tmp_repo" commit -m "wip: second batch" >/dev/null 2>&1

    local count_before
    count_before="$(git -C "$tmp_repo" rev-list --count HEAD)"
    [ "$count_before" -eq 3 ]

    run _run_gsquash "$tmp_repo" "$target_hash"
    [ "$status" -eq 0 ]

    local count_after
    count_after="$(git -C "$tmp_repo" rev-list --count HEAD)"
    [ "$count_after" -eq 1 ]

    local head_msg
    head_msg="$(git -C "$tmp_repo" log -1 --pretty=%B | tr -d '\r\n')"
    [ "$head_msg" = "feat(core): initial target commit" ]

    [ -f "$tmp_repo/file2.txt" ]
    [ -f "$tmp_repo/file3.txt" ]
    grep -q "WIP edit 2" "$tmp_repo/file1.txt"
    [ -z "$(git -C "$tmp_repo" status --porcelain)" ]
}

@test "gsquash is a no-op when HEAD is already at target commit" {
    local tmp_repo="$BATS_TEST_TMPDIR/repo"
    _init_gsquash_repo "$tmp_repo"

    run _run_gsquash "$tmp_repo" HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nothing to squash: HEAD is already at target commit"* ]]
}

@test "gsquash rejects missing or empty commit argument" {
    local tmp_repo="$BATS_TEST_TMPDIR/repo"
    _init_gsquash_repo "$tmp_repo"

    run _run_gsquash "$tmp_repo"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage: gsquash <commit-hash>"* ]]

    run _run_gsquash "$tmp_repo" ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage: gsquash <commit-hash>"* ]]
}

@test "gsquash rejects execution outside a git work tree" {
    local non_git_dir="$BATS_TEST_TMPDIR/non_git"
    mkdir -p "$non_git_dir"

    run _run_gsquash "$non_git_dir" HEAD
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error: not inside a git work tree"* ]]
}

@test "gsquash rejects an invalid commit hash" {
    local tmp_repo="$BATS_TEST_TMPDIR/repo"
    _init_gsquash_repo "$tmp_repo"

    run _run_gsquash "$tmp_repo" "invalid_commit_hash_12345"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error: invalid commit 'invalid_commit_hash_12345'"* ]]
}

@test "gsquash rejects a commit that is not an ancestor of HEAD" {
    local tmp_repo="$BATS_TEST_TMPDIR/repo"
    _init_gsquash_repo "$tmp_repo"
    local initial_branch
    initial_branch="$(git -C "$tmp_repo" rev-parse --abbrev-ref HEAD)"

    git -C "$tmp_repo" checkout -b other-branch >/dev/null 2>&1
    echo "other branch change" >"$tmp_repo/other.txt"
    git -C "$tmp_repo" add other.txt
    git -C "$tmp_repo" commit -m "feat: unrelated branch" >/dev/null 2>&1
    local unrelated_hash
    unrelated_hash="$(git -C "$tmp_repo" rev-parse HEAD)"
    git -C "$tmp_repo" checkout "$initial_branch" >/dev/null 2>&1

    run _run_gsquash "$tmp_repo" "$unrelated_hash"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error: commit '$unrelated_hash' is not an ancestor of HEAD"* ]]
}

@test "gsquash rejects a dirty working tree" {
    local tmp_repo="$BATS_TEST_TMPDIR/repo"
    _init_gsquash_repo "$tmp_repo"
    local base_hash
    base_hash="$(git -C "$tmp_repo" rev-parse HEAD)"

    echo "wip line" >>"$tmp_repo/base.txt"
    git -C "$tmp_repo" commit -am "wip: add line" >/dev/null 2>&1
    echo "unstaged dirty line" >>"$tmp_repo/base.txt"

    run _run_gsquash "$tmp_repo" "$base_hash"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error: working tree is not clean; commit or stash changes first"* ]]
}

@test "gsquash rejects merge commits between target and HEAD and leaves HEAD untouched" {
    local tmp_repo="$BATS_TEST_TMPDIR/repo"
    _init_gsquash_repo "$tmp_repo"
    local base_sha
    base_sha="$(git -C "$tmp_repo" rev-parse HEAD)"
    local initial_branch
    initial_branch="$(git -C "$tmp_repo" rev-parse --abbrev-ref HEAD)"

    git -C "$tmp_repo" checkout -b side-branch >/dev/null 2>&1
    echo "side change" >"$tmp_repo/side.txt"
    git -C "$tmp_repo" add side.txt
    git -C "$tmp_repo" commit -m "feat: side branch commit" >/dev/null 2>&1

    git -C "$tmp_repo" checkout "$initial_branch" >/dev/null 2>&1
    git -C "$tmp_repo" merge --no-ff side-branch -m "merge: side branch" >/dev/null 2>&1

    local head_before
    head_before="$(git -C "$tmp_repo" rev-parse HEAD)"

    run _run_gsquash "$tmp_repo" "$base_sha"
    [ "$status" -ne 0 ]
    [[ "$output" == *"merge commits exist"* ]]

    local head_after
    head_after="$(git -C "$tmp_repo" rev-parse HEAD)"
    [ "$head_after" = "$head_before" ]
}
