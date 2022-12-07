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

# Get the current user
USER=$(whoami)

if [ "$OS" == "ubuntu" ]; then
    sudo apt update -y
    sudo apt install -y docker.io
    sudo systemctl enable --now docker
    sudo usermod -aG docker ${USER}
elif [ "$OS" == "amzn" ]; then
    sudo dnf update -y
    sudo dnf install -y docker
    sudo systemctl enable --now docker
    sudo usermod -aG docker ${USER}
else
    echo "Unsupported OS"
    exit 1
fi

# Install docker-compose
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.36.0/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Verify Docker installation
docker --version
docker compose version
