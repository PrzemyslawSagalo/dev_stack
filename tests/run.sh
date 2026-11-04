#!/usr/bin/env bash
set -euo pipefail

SUITE="${1:-unit}"
DISTRO="${2:-ubuntu:22.04}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

case "$DISTRO" in
    ubuntu|ubuntu:22.04)
        IMAGE="ubuntu:22.04"
        ;;
    ubuntu:24.04)
        IMAGE="ubuntu:24.04"
        ;;
    amazonlinux|amazonlinux:2023|amzn|amzn2023)
        IMAGE="amazonlinux:2023"
        ;;
    *)
        IMAGE="$DISTRO"
        ;;
esac

echo "=========================================================="
echo " Starting $SUITE tests in $IMAGE"
echo " Repository root: $REPO_DIR"
echo "=========================================================="

if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker daemon is not running." >&2
    exit 1
fi

docker run --rm -t \
    -v "$REPO_DIR:/dev_stack:ro" \
    "$IMAGE" \
    bash -c '
        set -euo pipefail
        SUITE="$1"

        echo "==> [Test Setup: $SUITE] Initializing clean container environment..."
        if [ -f /etc/debian_version ]; then
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get install -y -qq sudo bash git
        else
            dnf install -y -q sudo bash shadow-utils git
        fi

        useradd -m -s /bin/bash devuser
        echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser
        chmod 0440 /etc/sudoers.d/devuser

        echo "==> [Test Setup: Bats] Installing bats-core..."
        rm -rf /tmp/bats-core
        git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core
        /tmp/bats-core/install.sh /usr/local
        rm -rf /tmp/bats-core

        echo "==> [Test Setup: Workspace] Preparing workspace for devuser..."
        rm -rf /home/devuser/dev_stack
        cp -a /dev_stack /home/devuser/dev_stack
        chown -R devuser:devuser /home/devuser/dev_stack

        if [ "$SUITE" = "smoke" ]; then
            echo "==> [Smoke Test: Installation] Running ./bootstrap.sh..."
            sudo -u devuser bash -l -c "
                set -euo pipefail
                cd ~/dev_stack
                ./bootstrap.sh
            "
            echo "==> [Smoke Test: Verification] Running bats smoke tests..."
            sudo -u devuser bash -l -c "
                cd ~/dev_stack
                bats tests/test_smoke/smoke.bats
            "
        else
            echo "==> [Unit Test: Verification] Running bats unit tests..."
            sudo -u devuser bash -l -c "
                cd ~/dev_stack
                bats tests/unit/test_bootstrap.bats
            "
        fi

        echo "==> [Test SUCCESS: $SUITE] Completed successfully!"
    ' bash "$SUITE"
