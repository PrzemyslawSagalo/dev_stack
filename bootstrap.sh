#!/bin/sh
set -eu

# Ensure script runs under Bash if available, or install and re-exec under Bash
if [ -z "${BASH_VERSION:-}" ]; then
    if command -v bash >/dev/null 2>&1; then
        if [ -f "$0" ]; then
            exec bash "$0" "$@"
        fi
    fi
fi

if [ -n "${BASH_VERSION:-}" ]; then
    set -o pipefail
fi

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
    echo "==> Detected Debian/Ubuntu family ($PKG_MGR). Installing base dependencies..."
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get update
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y git make python3 python3-pip sudo bash

    if ! command -v ansible-playbook >/dev/null 2>&1; then
        echo "==> Resolving Ansible installation..."
        INSTALL_LOG=$(mktemp)
        if $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y ansible >"$INSTALL_LOG" 2>&1; then
            echo "==> Successfully installed ansible meta-package via apt-get."
            rm -f "$INSTALL_LOG"
        elif $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y ansible-core >"$INSTALL_LOG" 2>&1; then
            echo "==> Successfully installed ansible-core via apt-get."
            rm -f "$INSTALL_LOG"
        else
            echo "==> APT packages (ansible, ansible-core) unavailable via apt-get."
            echo "    Details from apt-get attempt:"
            sed 's/^/    /' "$INSTALL_LOG"
            rm -f "$INSTALL_LOG"
            echo "==> Falling back to python3 -m pip install ansible-core..."
            if [ "$(id -u)" -eq 0 ]; then
                python3 -m pip install --no-cache-dir ansible-core
            else
                python3 -m pip install --user --no-cache-dir ansible-core
            fi
        fi
    else
        echo "==> ansible-playbook already installed. Skipping installation."
    fi
elif command -v dnf >/dev/null 2>&1 || command -v microdnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
    PKG_MGR="yum"
    if command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
    elif command -v microdnf >/dev/null 2>&1; then
        PKG_MGR="microdnf"
    fi
    echo "==> Detected RHEL/Amazon Linux family ($PKG_MGR). Installing base dependencies..."
    if [ "$PKG_MGR" = "microdnf" ]; then
        # Install dnf, python3-dnf bindings, bash, and sudo so downstream Ansible plays succeed
        echo "==> Installing base packages and DNF bindings via microdnf..."
        $SUDO "$PKG_MGR" install -y git make python3 python3-pip dnf python3-dnf sudo bash
        if ! command -v dnf >/dev/null 2>&1; then
            echo "Error: Failed to install 'dnf' via microdnf. Downstream Ansible roles require dnf." >&2
            exit 1
        fi
        PKG_MGR="dnf"
    else
        $SUDO "$PKG_MGR" install -y git make python3 python3-pip sudo bash
    fi

    if ! command -v ansible-playbook >/dev/null 2>&1; then
        echo "==> Resolving Ansible installation..."
        INSTALL_LOG=$(mktemp)
        if $SUDO "$PKG_MGR" install -y ansible >"$INSTALL_LOG" 2>&1; then
            echo "==> Successfully installed ansible meta-package via $PKG_MGR."
            rm -f "$INSTALL_LOG"
        elif $SUDO "$PKG_MGR" install -y ansible-core >"$INSTALL_LOG" 2>&1; then
            echo "==> Successfully installed ansible-core via $PKG_MGR."
            rm -f "$INSTALL_LOG"
        else
            echo "==> RPM packages (ansible, ansible-core) unavailable via $PKG_MGR."
            echo "    Details from $PKG_MGR attempt:"
            sed 's/^/    /' "$INSTALL_LOG"
            rm -f "$INSTALL_LOG"
            echo "==> Falling back to python3 -m pip install ansible-core..."
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

# Re-exec under Bash now that bash and dependencies are guaranteed to be present
if [ -z "${BASH_VERSION:-}" ]; then
    if command -v bash >/dev/null 2>&1; then
        if [ -f "$0" ]; then
            exec bash "$0" "$@"
        fi
    fi
fi

# Ensure local python binary paths are available on PATH across all distributions
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
hash -r 2>/dev/null || true

REPO_URL="https://github.com/PrzemyslawSagalo/dev_stack.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd || pwd)"

# Workspace resolution: prioritize script directory when inside repo, then validated current working directory
if [ -f "$SCRIPT_DIR/setup.yml" ] && [ -d "$SCRIPT_DIR/roles/system" ] && [ -f "$SCRIPT_DIR/Makefile" ]; then
    echo "==> Detected in-repo workspace via script directory. Bypassing clone/pull..."
    DEST_DIR="$SCRIPT_DIR"
elif [ -f "./setup.yml" ] && [ -d "./roles/system" ] && [ -f "./Makefile" ]; then
    echo "==> Detected in-repo workspace via current directory. Bypassing clone/pull..."
    DEST_DIR="$PWD"
else
    DEST_DIR="$HOME/.dev_env"
    if [ ! -d "$DEST_DIR/.git" ]; then
        echo "==> Cloning repository..."
        rm -rf "$DEST_DIR"
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
