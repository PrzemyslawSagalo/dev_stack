#!/bin/bash
set -euo pipefail

echo "==> Starting environment initialization (Bootstrap)..."

# Detect package manager
if command -v apt-get >/dev/null 2>&1; then
    echo "==> Detected Debian/Ubuntu family. Installing Git and Ansible..."
    sudo apt-get update
    sudo apt-get install -y git ansible make
elif command -v yum >/dev/null 2>&1; then
    echo "==> Detected RHEL/Amazon Linux family. Installing Git and Ansible..."
    sudo yum install -y git ansible make
else
    echo "Unknown package manager. Script supports apt-get and yum/dnf."
    exit 1
fi

REPO_URL="https://github.com/PrzemyslawSagalo/dev_stack.git"
DEST_DIR="$HOME/.dev_env"

if [ ! -d "$DEST_DIR" ]; then
    echo "==> Cloning repository..."
    git clone "$REPO_URL" "$DEST_DIR"
else
    echo "==> Repository already exists. Updating..."
    cd "$DEST_DIR"
    git pull origin main
fi

echo "==> Handing over execution to Ansible..."
cd "$DEST_DIR"
make setup
