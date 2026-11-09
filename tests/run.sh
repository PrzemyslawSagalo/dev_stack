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
            sudo -H -u devuser bash -l -c 'set -euo pipefail; cd ~/dev_stack; "$@"' _ "$@"
        }

        case "$SUITE" in
            unit)
                echo "==> [Suite: Unit] Running unit tests..."
                run_as_devuser bats --print-output-on-failure tests/unit
                ;;
            smoke)
                echo "==> [Suite: Smoke] Installing system environment..."
                run_as_devuser ./bootstrap.sh
                echo "==> [Suite: Smoke] Running smoke tests..."
                run_as_devuser bats --print-output-on-failure tests/smoke
                ;;
            e2e)
                echo "==> [Suite: E2E] Installing system environment..."
                run_as_devuser ./bootstrap.sh
                echo "==> [Suite: E2E] Running end-to-end tests..."
                run_as_devuser env XDG_CONFIG_HOME=/home/devuser/dev_stack/roles/nvim/files nvim --headless -c "PlenaryBustedDirectory tests/e2e/nvim"
                ;;
            *)
                echo "Error: Unknown test suite: $SUITE (supported: unit, smoke, e2e)" >&2
                exit 1
                ;;
        esac

        echo "==> [Test SUCCESS: $SUITE] Completed successfully!"
    ' bash "$SUITE"
