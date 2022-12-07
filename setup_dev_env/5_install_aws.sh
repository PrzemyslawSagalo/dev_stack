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

if [ "$OS" == "ubuntu" ]; then
    sudo apt update -y
    sudo apt install -y unzip
elif [ "$OS" == "amzn" ]; then
    sudo dnf update -y
    sudo dnf install -y unzip
else
    echo "Unsupported OS"
    exit 1
fi

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# Verify the installation
aws --version
