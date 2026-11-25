#!/usr/bin/env bats

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    # shellcheck disable=SC1091
    source "$BATS_TEST_DIRNAME/../../../roles/dotfiles/files/bash/.bash_aliases"

    local repo="$BATS_TEST_TMPDIR/repo"
    git init -b main "$repo" >/dev/null 2>&1
    cd "$repo" || return 1

    git config user.name "Test User"
    git config user.email "test@example.com"
    echo "Initial line" >base.txt
    git add base.txt
    git commit -m "feat(core): initial target commit" >/dev/null 2>&1
    BASE_HASH="$(git rev-parse HEAD)"
}

@test "gsquash collapses subsequent wip commits into target commit preserving its message and all file changes" {
    echo "wip 1" >wip1.txt
    git add wip1.txt
    git commit -m "wip: first batch" >/dev/null 2>&1

    echo "wip 2" >wip2.txt
    git add wip2.txt
    git commit -m "wip: second batch" >/dev/null 2>&1

    run gsquash "$BASE_HASH"
    assert_success

    run git log --format=%s
    assert_output "feat(core): initial target commit"
    assert_file_exists "wip1.txt"
    assert_file_exists "wip2.txt"
}

@test "gsquash is a no-op when HEAD is already at target commit" {
    run gsquash HEAD
    assert_success
    assert_output --partial "Nothing to squash: HEAD is already at target commit"
}

@test "gsquash with no argument collapses all wip commits into the first commit on the feature branch" {
    git checkout -b feat/test >/dev/null 2>&1

    echo "api" >api.txt
    git add api.txt
    git commit -m "feat(api): add validation" >/dev/null 2>&1

    echo "wip 1" >wip1.txt
    git add wip1.txt
    git commit -m "wip: first" >/dev/null 2>&1

    echo "wip 2" >wip2.txt
    git add wip2.txt
    git commit -m "wip: second" >/dev/null 2>&1

    run gsquash
    assert_success

    run git log --format=%s "${BASE_HASH}..HEAD"
    assert_output "feat(api): add validation"
    assert_file_exists "api.txt"
    assert_file_exists "wip1.txt"
    assert_file_exists "wip2.txt"
}

@test "gsquash collapses wip commits before and after rebasing onto updated main" {
    git checkout -b feat/test >/dev/null 2>&1
    echo "api" >api.txt
    git add api.txt
    git commit -m "feat(api): add validation" >/dev/null 2>&1

    echo "wip 1" >wip1.txt
    git add wip1.txt
    git commit -m "wip: before rebase" >/dev/null 2>&1

    git checkout main >/dev/null 2>&1
    echo "upstream" >upstream.txt
    git add upstream.txt
    git commit -m "feat(main): upstream change" >/dev/null 2>&1

    git checkout feat/test >/dev/null 2>&1
    git rebase main >/dev/null 2>&1

    echo "wip 2" >wip2.txt
    git add wip2.txt
    git commit -m "wip: after rebase" >/dev/null 2>&1

    run gsquash
    assert_success

    run git log --format=%s main..HEAD
    assert_output "feat(api): add validation"
    assert_file_exists "upstream.txt"
    assert_file_exists "api.txt"
    assert_file_exists "wip1.txt"
    assert_file_exists "wip2.txt"
}

@test "gsquash prints usage and exits 0 with -h" {
    run gsquash -h
    assert_success
    assert_output --partial "Usage: gsquash [commit-hash]"
}

@test "gsquash prints usage and exits 0 with --help" {
    run gsquash --help
    assert_success
    assert_output --partial "Usage: gsquash [commit-hash]"
}

@test "gsquash rejects more than one argument" {
    run gsquash HEAD HEAD
    assert_failure
    assert_output --partial "Usage: gsquash [commit-hash]"
}

@test "gsquash rejects empty commit argument" {
    run gsquash ""
    assert_failure
    assert_output --partial "Usage: gsquash [commit-hash]"
}

@test "gsquash with no argument fails when branch has no commits ahead of base branch" {
    run gsquash
    assert_failure
    assert_output --partial "no commits on current branch ahead of"
}

@test "gsquash rejects execution outside a git work tree" {
    cd "$BATS_TEST_TMPDIR" || return 1

    run gsquash HEAD
    assert_failure
    assert_output --partial "Error: not inside a git work tree"
}

@test "gsquash rejects an invalid commit hash" {
    run gsquash invalid_commit_hash_12345
    assert_failure
    assert_output --partial "Error: invalid commit 'invalid_commit_hash_12345'"
}

@test "gsquash rejects a commit that is not an ancestor of HEAD" {
    git checkout -b other-branch >/dev/null 2>&1
    git commit --allow-empty -m "feat: unrelated branch" >/dev/null 2>&1
    git checkout main >/dev/null 2>&1

    run gsquash other-branch
    assert_failure
    assert_output --partial "Error: commit 'other-branch' is not an ancestor of HEAD"
}

@test "gsquash rejects a dirty working tree" {
    echo "dirty" >>base.txt

    run gsquash "$BASE_HASH"
    assert_failure
    assert_output --partial "Error: working tree is not clean; commit or stash changes first"
}

@test "gsquash rejects merge commits between target and HEAD" {
    git checkout -b side-branch >/dev/null 2>&1
    git commit --allow-empty -m "feat: side branch commit" >/dev/null 2>&1
    git checkout main >/dev/null 2>&1
    git merge --no-ff side-branch -m "merge: side branch" >/dev/null 2>&1

    run gsquash "$BASE_HASH"
    assert_failure
    assert_output --partial "merge commits exist"
}
