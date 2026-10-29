#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_SCRIPT="$REPO_ROOT/bootstrap.sh"

# Source shared test helpers
# shellcheck source=tests/test_helpers.sh
source "$REPO_ROOT/tests/test_helpers.sh"

# Ensure docker daemon is accessible
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "Warning: Docker daemon is not available. Skipping container smoke tests." >&2
    exit 0
fi

test_amazonlinux_2023() {
    local workspace
    workspace="$(mktemp -d)"
    trap 'rm -rf "${workspace:-}"' RETURN

    setup_container_workspace "$workspace"

    docker run --rm \
        -v "$BOOTSTRAP_SCRIPT:/bootstrap.sh:ro" \
        -v "$workspace:/workspace:rw" \
        -w "/workspace" \
        amazonlinux:2023 \
        bash -c "bash /bootstrap.sh" > "$workspace/output.log" 2>&1 || {
            cat "$workspace/output.log" >&2
            return 1
        }

    if ! grep -q "MOCK_MAKE_SETUP_SUCCESS" "$workspace/output.log"; then
        echo "Expected MOCK_MAKE_SETUP_SUCCESS on AL2023" >&2
        cat "$workspace/output.log" >&2
        return 1
    fi
    return 0
}

test_ubi9() {
    local workspace
    workspace="$(mktemp -d)"
    trap 'rm -rf "${workspace:-}"' RETURN

    setup_container_workspace "$workspace"

    docker run --rm \
        -v "$BOOTSTRAP_SCRIPT:/bootstrap.sh:ro" \
        -v "$workspace:/workspace:rw" \
        -w "/workspace" \
        registry.access.redhat.com/ubi9/ubi:latest \
        bash -c "bash /bootstrap.sh" > "$workspace/output.log" 2>&1 || {
            cat "$workspace/output.log" >&2
            return 1
        }

    if ! grep -q "MOCK_MAKE_SETUP_SUCCESS" "$workspace/output.log"; then
        echo "Expected MOCK_MAKE_SETUP_SUCCESS on UBI 9" >&2
        cat "$workspace/output.log" >&2
        return 1
    fi
    return 0
}

test_ubuntu_2204() {
    local workspace
    workspace="$(mktemp -d)"
    trap 'rm -rf "${workspace:-}"' RETURN

    setup_container_workspace "$workspace"

    docker run --rm \
        -v "$BOOTSTRAP_SCRIPT:/bootstrap.sh:ro" \
        -v "$workspace:/workspace:rw" \
        -w "/workspace" \
        ubuntu:22.04 \
        bash -c "bash /bootstrap.sh" > "$workspace/output.log" 2>&1 || {
            cat "$workspace/output.log" >&2
            return 1
        }

    if ! grep -q "MOCK_MAKE_SETUP_SUCCESS" "$workspace/output.log"; then
        echo "Expected MOCK_MAKE_SETUP_SUCCESS on Ubuntu 22.04" >&2
        cat "$workspace/output.log" >&2
        return 1
    fi
    return 0
}

test_non_root_no_sudo() {
    local workspace
    workspace="$(mktemp -d)"
    trap 'rm -rf "${workspace:-}"' RETURN

    docker run --rm \
        -v "$BOOTSTRAP_SCRIPT:/bootstrap.sh:ro" \
        registry.access.redhat.com/ubi9/ubi:latest \
        bash -c "useradd -m testuser && su testuser -c 'bash /bootstrap.sh'" > "$workspace/output.log" 2>&1 || true

    if ! grep -qi "sudo.*not found\|install sudo\|run.*root" "$workspace/output.log"; then
        echo "Expected failure message about sudo for non-root, got:" >&2
        cat "$workspace/output.log" >&2
        return 1
    fi
    return 0
}

test_ubi9_minimal() {
    local workspace
    workspace="$(mktemp -d)"
    trap 'rm -rf "${workspace:-}"' RETURN

    setup_container_workspace "$workspace" 'command -v dnf
python3 -c "import dnf"'

    docker run --rm \
        -v "$BOOTSTRAP_SCRIPT:/bootstrap.sh:ro" \
        -v "$workspace:/workspace:rw" \
        -w "/workspace" \
        registry.access.redhat.com/ubi9/ubi-minimal:latest \
        /bin/sh /bootstrap.sh > "$workspace/output.log" 2>&1 || {
            cat "$workspace/output.log" >&2
            return 1
        }

    if ! grep -q "MOCK_MAKE_SETUP_SUCCESS" "$workspace/output.log"; then
        echo "Expected MOCK_MAKE_SETUP_SUCCESS on UBI 9 Minimal" >&2
        cat "$workspace/output.log" >&2
        return 1
    fi
    return 0
}

run_test "Amazon Linux 2023 Container Smoke Test" test_amazonlinux_2023
run_test "Red Hat UBI 9 Container Smoke Test" test_ubi9
run_test "Red Hat UBI 9 Minimal (microdnf) Container Smoke Test" test_ubi9_minimal
run_test "Ubuntu 22.04 Container Smoke Test" test_ubuntu_2204
run_test "Non-root without sudo Container Test" test_non_root_no_sudo

echo "========================================"
echo "All $PASS_COUNT / $TEST_COUNT container smoke tests passed successfully."
