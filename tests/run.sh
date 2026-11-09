#!/usr/bin/env bash
set -euo pipefail

SUITE="${1:-unit}"
DISTRO="${2:-ubuntu:24.04}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

case "$DISTRO" in
    ubuntu | ubuntu:24.04)
        IMAGE="ubuntu:24.04"
        ;;
    amazonlinux | amazonlinux:2023 | amzn | amzn2023)
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

        echo "==> [Setup: Dependencies] Installing bootstrap prerequisites..."
        if [ -f /etc/debian_version ]; then
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get install -y -qq sudo bash git
        else
            dnf install -y -q sudo bash shadow-utils git
        fi

        echo "==> [Setup: User] Provisioning devuser..."
        useradd -m -s /bin/bash devuser
        echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser
        chmod 0440 /etc/sudoers.d/devuser

        echo "==> [Setup: Bats] Installing bats-core..."
        rm -rf /tmp/bats-core
        git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core
        /tmp/bats-core/install.sh /usr/local
        rm -rf /tmp/bats-core

        echo "==> [Setup: Workspace] Preparing workspace for devuser..."
        rm -rf /home/devuser/dev_stack
        cp -a /dev_stack /home/devuser/dev_stack
        chown -R devuser:devuser /home/devuser/dev_stack

        run_as_devuser() {
            sudo -u devuser bash -l -c "set -euo pipefail; cd ~/dev_stack; $*"
        }

        case "$SUITE" in
            unit)
                echo "==> [Suite: Unit] Running bats unit tests..."
                run_as_devuser bats tests/unit/test_bootstrap.bats
                ;;
            smoke)
                echo "==> [Suite: Smoke] Installing system environment..."
                run_as_devuser ./bootstrap.sh
                echo "==> [Suite: Smoke] Running bats smoke tests..."
                run_as_devuser bats tests/smoke/smoke.bats
                echo "==> [Suite: Smoke] Running Neovim behavioral test suite..."
                run_as_devuser make test-nvim
                ;;
            nvim | e2e)
                echo "==> [Suite: Neovim] Installing system environment..."
                run_as_devuser ./bootstrap.sh
                echo "==> [Suite: Neovim] Running make test-nvim..."
                run_as_devuser make test-nvim
                ;;
            all)
                echo "==> [Suite: All] Installing system environment..."
                run_as_devuser ./bootstrap.sh
                echo "==> [Suite: All] Running bats unit tests..."
                run_as_devuser bats tests/unit/test_bootstrap.bats
                echo "==> [Suite: All] Running bats smoke tests..."
                run_as_devuser bats tests/smoke/smoke.bats
                echo "==> [Suite: All] Running Neovim behavioral test suite..."
                run_as_devuser make test-nvim
                ;;
            *)
                echo "Error: Unknown test suite: $SUITE (supported: unit, smoke, nvim, all)" >&2
                exit 1
                ;;
        esac

        echo "==> [Test SUCCESS: $SUITE] Completed successfully!"
    ' bash "$SUITE"
