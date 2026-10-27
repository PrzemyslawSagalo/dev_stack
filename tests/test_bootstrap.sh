#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_SCRIPT="$REPO_ROOT/bootstrap.sh"

TEST_COUNT=0
PASS_COUNT=0

run_test() {
    local test_name="$1"
    shift
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "========================================"
    echo "Running Container Test ${TEST_COUNT}: ${test_name}"
    echo "========================================"
    if "$@"; then
        echo "PASS: Container Test ${TEST_COUNT} - ${test_name}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: Container Test ${TEST_COUNT} - ${test_name}" >&2
        return 1
    fi
}

# Ensure docker daemon is accessible
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "Warning: Docker daemon is not available. Skipping container smoke tests." >&2
    exit 0
fi

test_amazonlinux_2023() {
    local workspace
    workspace="$(mktemp -d)"

    cat << 'EOF' > "$workspace/setup.yml"
---
- name: Smoke test playbook
  hosts: localhost
  connection: local
  tasks:
    - name: Ping
      ansible.builtin.ping:
EOF

    cat << 'EOF' > "$workspace/Makefile"
setup:
	@echo "==> MOCK_MAKE_SETUP_START"
	ansible-playbook --version
	@echo "==> MOCK_MAKE_SETUP_SUCCESS"
EOF

    docker run --rm \
        -v "$BOOTSTRAP_SCRIPT:/bootstrap.sh:ro" \
        -v "$workspace:/workspace:rw" \
        -w "/workspace" \
        amazonlinux:2023 \
        bash -c "bash /bootstrap.sh" > "$workspace/output.log" 2>&1 || {
            cat "$workspace/output.log" >&2
            rm -rf "$workspace"
            return 1
        }

    local result=0
    if ! grep -q "MOCK_MAKE_SETUP_SUCCESS" "$workspace/output.log"; then
        echo "Expected MOCK_MAKE_SETUP_SUCCESS on AL2023" >&2
        cat "$workspace/output.log" >&2
        result=1
    fi
    rm -rf "$workspace"
    return $result
}

test_ubi9() {
    local workspace
    workspace="$(mktemp -d)"

    cat << 'EOF' > "$workspace/setup.yml"
---
- name: Smoke test playbook
  hosts: localhost
  connection: local
  tasks:
    - name: Ping
      ansible.builtin.ping:
EOF

    cat << 'EOF' > "$workspace/Makefile"
setup:
	@echo "==> MOCK_MAKE_SETUP_START"
	ansible-playbook --version
	@echo "==> MOCK_MAKE_SETUP_SUCCESS"
EOF

    docker run --rm \
        -v "$BOOTSTRAP_SCRIPT:/bootstrap.sh:ro" \
        -v "$workspace:/workspace:rw" \
        -w "/workspace" \
        registry.access.redhat.com/ubi9/ubi:latest \
        bash -c "bash /bootstrap.sh" > "$workspace/output.log" 2>&1 || {
            cat "$workspace/output.log" >&2
            rm -rf "$workspace"
            return 1
        }

    local result=0
    if ! grep -q "MOCK_MAKE_SETUP_SUCCESS" "$workspace/output.log"; then
        echo "Expected MOCK_MAKE_SETUP_SUCCESS on UBI 9" >&2
        cat "$workspace/output.log" >&2
        result=1
    fi
    rm -rf "$workspace"
    return $result
}

test_ubuntu_2204() {
    local workspace
    workspace="$(mktemp -d)"

    cat << 'EOF' > "$workspace/setup.yml"
---
- name: Smoke test playbook
  hosts: localhost
  connection: local
  tasks:
    - name: Ping
      ansible.builtin.ping:
EOF

    cat << 'EOF' > "$workspace/Makefile"
setup:
	@echo "==> MOCK_MAKE_SETUP_START"
	ansible-playbook --version
	@echo "==> MOCK_MAKE_SETUP_SUCCESS"
EOF

    docker run --rm \
        -v "$BOOTSTRAP_SCRIPT:/bootstrap.sh:ro" \
        -v "$workspace:/workspace:rw" \
        -w "/workspace" \
        ubuntu:22.04 \
        bash -c "bash /bootstrap.sh" > "$workspace/output.log" 2>&1 || {
            cat "$workspace/output.log" >&2
            rm -rf "$workspace"
            return 1
        }

    local result=0
    if ! grep -q "MOCK_MAKE_SETUP_SUCCESS" "$workspace/output.log"; then
        echo "Expected MOCK_MAKE_SETUP_SUCCESS on Ubuntu 22.04" >&2
        cat "$workspace/output.log" >&2
        result=1
    fi
    rm -rf "$workspace"
    return $result
}

test_non_root_no_sudo() {
    local workspace
    workspace="$(mktemp -d)"

    docker run --rm \
        -v "$BOOTSTRAP_SCRIPT:/bootstrap.sh:ro" \
        registry.access.redhat.com/ubi9/ubi:latest \
        bash -c "useradd -m testuser && su testuser -c 'bash /bootstrap.sh'" > "$workspace/output.log" 2>&1 || true

    local result=0
    if ! grep -qi "sudo.*not found\|install sudo\|run.*root" "$workspace/output.log"; then
        echo "Expected failure message about sudo for non-root, got:" >&2
        cat "$workspace/output.log" >&2
        result=1
    fi
    rm -rf "$workspace"
    return $result
}

run_test "Amazon Linux 2023 Container Smoke Test" test_amazonlinux_2023
run_test "Red Hat UBI 9 Container Smoke Test" test_ubi9
run_test "Ubuntu 22.04 Container Smoke Test" test_ubuntu_2204
run_test "Non-root without sudo Container Test" test_non_root_no_sudo

echo "========================================"
echo "All $PASS_COUNT / $TEST_COUNT container smoke tests passed successfully."
