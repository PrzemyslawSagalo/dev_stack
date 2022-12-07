#!/bin/bash

# Exit immediately if a pipeline returns a non-zero status.
set -e 

USER_NAME=''
USER_EMAIL=''

# Create dir for configs
mkdir -p ~/.config

# Detect the OS and install dev tools
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "Unsupported OS"
    exit 1
fi

if [ "$OS" == "ubuntu" ]; then
    sudo apt update -y 
    sudo apt install -y git \
                        wget \
                        htop \
                        zip \
                        apt-utils \
                        net-tools \
                        dos2unix \
                        tree \
                        tmux
elif [ "$OS" == "amzn" ]; then
    sudo dnf update -y 
    sudo dnf install -y git \
                        wget \
                        htop \
                        zip \
                        net-tools \
                        dos2unix \
                        tree \
                        tmux
else
    echo "Unsupported OS"
    exit 1
fi

# Install dotfiles
curl -sSL https://raw.githubusercontent.com/PrzemyslawSagalo/dotfiles/main/install.sh | sh

# Configure git
git config --global core.editor "nvim"
git config --global user.name "$USER_NAME"
git config --global user.email $USER_EMAIL
git config --global init.defaultBranch main
echo "Git configured"
git config --global --list

ssh-keygen -t ed25519 -C $USER_EMAIL
cat ~/.ssh/id_ed25519.pub
echo 'https://github.com/settings/keys'
