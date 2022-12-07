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
    sudo apt install -y cmake \
                        lldb \
                        build-essential
elif [ "$OS" == "amzn" ]; then
    sudo dnf update -y
    sudo dnf install -y cmake \
                        lldb \
                        gcc \
                        gcc-c++ \
                        make
else
    echo "Unsupported OS"
    exit 1
fi
