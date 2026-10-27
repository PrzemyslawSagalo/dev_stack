#!/bin/bash
set -euo pipefail

echo "==> Starting environment initialization (Bootstrap)..."

# Privilege escalation check & sudo resolution
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if ! command -v sudo >/dev/null 2>&1; then
        echo "Error: 'sudo' command not found. Please install sudo or run as root." >&2
        exit 1
    fi
    SUDO="sudo"
fi

# Detect package manager (apt-get, dnf, microdnf, or yum)
if command -v apt-get >/dev/null 2>&1; then
    PKG_MGR="apt-get"
    echo "==> Detected Debian/Ubuntu family ($PKG_MGR). Installing Git and Ansible..."
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get update
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y git ansible make
elif command -v dnf >/dev/null 2>&1 || command -v microdnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
    PKG_MGR="yum"
    if command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
    elif command -v microdnf >/dev/null 2>&1; then
        PKG_MGR="microdnf"
    fi
    echo "==> Detected RHEL/Amazon Linux family ($PKG_MGR). Installing base dependencies..."
    $SUDO "$PKG_MGR" install -y git make python3 python3-pip

    if ! command -v ansible-playbook >/dev/null 2>&1; then
        echo "==> Resolving Ansible installation..."
        if $SUDO "$PKG_MGR" install -y ansible >/dev/null 2>&1; then
            echo "==> Successfully installed ansible meta-package via $PKG_MGR."
        elif $SUDO "$PKG_MGR" install -y ansible-core >/dev/null 2>&1; then
            echo "==> Successfully installed ansible-core via $PKG_MGR."
        else
            echo "==> RPM packages unavailable. Falling back to python3 -m pip install ansible-core..."
            if [ "$(id -u)" -eq 0 ]; then
                python3 -m pip install --no-cache-dir ansible-core
            else
                python3 -m pip install --user --no-cache-dir ansible-core
            fi
        fi
    else
        echo "==> ansible-playbook already installed. Skipping installation."
    fi
else
    echo "Error: Unknown package manager. Script supports apt-get, dnf, microdnf, or yum." >&2
    exit 1
fi

# Ensure local python binary paths are available on PATH across all distributions
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
hash -r

REPO_URL="https://github.com/PrzemyslawSagalo/dev_stack.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd || pwd)"

# Workspace resolution: prioritize script directory when inside repo, then current working directory
if [ -f "$SCRIPT_DIR/setup.yml" ]; then
    echo "==> Detected in-repo workspace via script directory. Bypassing clone/pull..."
    DEST_DIR="$SCRIPT_DIR"
elif [ -f "./setup.yml" ]; then
    echo "==> Detected in-repo workspace via current directory. Bypassing clone/pull..."
    DEST_DIR="$PWD"
else
    DEST_DIR="$HOME/.dev_env"
    if [ ! -d "$DEST_DIR" ]; then
        echo "==> Cloning repository..."
        git clone "$REPO_URL" "$DEST_DIR"
    else
        echo "==> Repository already exists. Updating..."
        cd "$DEST_DIR"
        git pull origin main
    fi
fi

echo "==> Handing over execution to Ansible..."
cd "$DEST_DIR"
make setup
