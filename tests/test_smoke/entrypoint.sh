#!/usr/bin/env bash
set -euo pipefail

echo "==> [Smoke Test: Setup] Initializing clean container environment..."

if [ -f /etc/debian_version ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq sudo bash git
    useradd -m -s /bin/bash devuser
    echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser
    chmod 0440 /etc/sudoers.d/devuser
elif [ -f /etc/amazon-linux-release ] || grep -q 'Amazon Linux' /etc/os-release 2>/dev/null; then
    dnf install -y -q sudo bash shadow-utils git
    useradd -m -s /bin/bash devuser
    echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser
    chmod 0440 /etc/sudoers.d/devuser
else
    echo "Error: Unsupported distribution inside container" >&2
    exit 1
fi

echo "==> [Smoke Test: Workspace] Preparing workspace for devuser..."
rm -rf /home/devuser/dev_stack
cp -a /dev_stack_src /home/devuser/dev_stack
chown -R devuser:devuser /home/devuser/dev_stack

echo "==> [Smoke Test: Installation] Running ./bootstrap.sh as devuser..."
sudo -u devuser bash -l -c "
    set -euo pipefail
    cd /home/devuser/dev_stack
    ./bootstrap.sh
"

echo "==> [Smoke Test: Bats] Installing bats-core from GitHub..."
rm -rf /tmp/bats-core
git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core
/tmp/bats-core/install.sh /usr/local
rm -rf /tmp/bats-core

echo "==> [Smoke Test: Verification] Running bats tests as devuser..."
sudo -u devuser bash -l -c "
    cd /home/devuser/dev_stack
    bats tests/test_smoke/smoke.bats
"

echo "==> [Smoke Test: SUCCESS] Environment initialized and verified successfully!"
