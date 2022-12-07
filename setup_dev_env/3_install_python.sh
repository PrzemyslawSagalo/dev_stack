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

# These packages are needed to correctly build Python in pyenv
# https://github.com/pyenv/pyenv/wiki#suggested-build-environment
if [ "$OS" == "ubuntu" ]; then
    sudo apt update -y
    sudo apt install -y build-essential \
                        zlib1g-dev \
                        libncurses5-dev \
                        libgdbm-dev \
                        libnss3-dev \
                        libssl-dev \
                        libreadline-dev \
                        libffi-dev \
                        libsqlite3-dev \
                        libbz2-dev
elif [ "$OS" == "amzn" ]; then
    sudo dnf update -y
    sudo dnf install -y gcc \
                        make \
                        patch \
                        bzip2 \
                        sqlite \
                        tk-devel \
                        xz-devel \
                        gdbm-libs \
                        zlib-devel \
                        ncurses-devel \
                        gdbm-devel \
                        nss-devel \
                        openssl-devel \
                        readline-devel \
                        libffi-devel \
                        sqlite-devel
else
    echo "Unsupported OS"
    exit 1
fi

# Install pyenv
curl https://pyenv.run | bash

# Add pyenv to bash so that it loads automatically
echo -e '\n# Pyenv configuration' >> ~/.bashrc
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo -e 'if command -v pyenv 1>/dev/null 2>&1; then\n  eval "$(pyenv init --path)"\nfi' >> ~/.bashrc
source ~/.bashrc

# Install specified Python versions using pyenv
PYTHON_VERSIONS=("3.9.21" "3.10.16" "3.11.11" "3.12.8")
for version in "${PYTHON_VERSIONS[@]}"; do
    pyenv install $version --verbose
done

# Set the global Python version
pyenv global 3.12.8

# Verify the installation
python --version
