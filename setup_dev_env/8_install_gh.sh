#!/bin/bash

# Exit immediately if a pipeline returns a non-zero status.
set -e 

# Detect the OS and install required packages
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "Unsupported OS"
    exit 1
fi

if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    echo "Installing GitHub CLI for Debian/Ubuntu..."
    (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y))
    sudo mkdir -p -m 755 /etc/apt/keyrings
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install gh -y
elif [[ "$OS" == "amzn" || "$OS" == "rhel" || "$OS" == "centos" || "$OS" == "fedora" ]]; then
    echo "Installing GitHub CLI for RPM-based OS (Amazon Linux/RHEL)..."
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y dnf-plugins-core
        sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
        sudo dnf install -y gh
    else
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
        sudo yum install -y gh
    fi
else
    echo "Unsupported OS: $OS"
    exit 1
fi

echo "GitHub CLI installation complete."
echo "Starting GitHub CLI authentication..."

# Auto trigger to authenticate
gh auth login
