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
    sudo apt install -y openjdk-21-jdk
elif [ "$OS" == "amzn" ]; then
    sudo dnf update -y
    # https://aws.amazon.com/corretto/
    sudo dnf install -y java-21-amazon-corretto-devel
else
    echo "Unsupported OS: $OS"
    exit 1
fi

java -version
