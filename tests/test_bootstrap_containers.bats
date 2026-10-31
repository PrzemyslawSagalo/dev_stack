#!/usr/bin/env bats
# shellcheck shell=bash

setup() {
    load "test_helpers.bash"
    test_setup
    if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
        skip "Docker daemon is not available"
    fi
}

teardown() {
    test_teardown
}

@test "Amazon Linux 2023 Container Smoke Test" {
    local workspace="$BATS_TEST_TMPDIR/al2023_ws"
    mkdir -p "$workspace"

    setup_container_workspace "$workspace"

    run docker run --rm \
        -v "$BOOTSTRAP_SCRIPT:/bootstrap.sh:ro" \
        -v "$workspace:/workspace:rw" \
        -w "/workspace" \
        amazonlinux:2023 \
        bash -c "bash /bootstrap.sh"
    assert_success
    assert_output --partial "MOCK_MAKE_SETUP_SUCCESS"
}

@test "Red Hat UBI 9 Container Smoke Test" {
    local workspace="$BATS_TEST_TMPDIR/ubi9_ws"
    mkdir -p "$workspace"

    setup_container_workspace "$workspace"

    run docker run --rm \
        -v "$BOOTSTRAP_SCRIPT:/bootstrap.sh:ro" \
        -v "$workspace:/workspace:rw" \
        -w "/workspace" \
        registry.access.redhat.com/ubi9/ubi:latest \
        bash -c "bash /bootstrap.sh"
    assert_success
    assert_output --partial "MOCK_MAKE_SETUP_SUCCESS"
}

@test "Red Hat UBI 9 Minimal (microdnf) Container Smoke Test" {
    local workspace="$BATS_TEST_TMPDIR/ubi9_min_ws"
    mkdir -p "$workspace"

    setup_container_workspace "$workspace" 'command -v dnf
python3 -c "import dnf"'

    run docker run --rm \
        -v "$BOOTSTRAP_SCRIPT:/bootstrap.sh:ro" \
        -v "$workspace:/workspace:rw" \
        -w "/workspace" \
        registry.access.redhat.com/ubi9/ubi-minimal:latest \
        /bin/sh /bootstrap.sh
    assert_success
    assert_output --partial "MOCK_MAKE_SETUP_SUCCESS"
}

@test "Ubuntu 22.04 Container Smoke Test" {
    local workspace="$BATS_TEST_TMPDIR/ubuntu_ws"
    mkdir -p "$workspace"

    setup_container_workspace "$workspace"

    run docker run --rm \
        -v "$BOOTSTRAP_SCRIPT:/bootstrap.sh:ro" \
        -v "$workspace:/workspace:rw" \
        -w "/workspace" \
        ubuntu:22.04 \
        bash -c "bash /bootstrap.sh"
    assert_success
    assert_output --partial "MOCK_MAKE_SETUP_SUCCESS"
}

@test "Non-root without sudo Container Test" {
    run docker run --rm \
        -v "$BOOTSTRAP_SCRIPT:/bootstrap.sh:ro" \
        registry.access.redhat.com/ubi9/ubi:latest \
        bash -c "useradd -m testuser && su testuser -c 'bash /bootstrap.sh'"
    assert_failure
    assert_output --regexp "sudo.*not found|install sudo|run.*root"
}
