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
    sudo apt install -y ripgrep \
                        exuberant-ctags \
                        fuse \
                        libfuse2 \
                        gettext gcc make
elif [ "$OS" == "amzn" ]; then
    sudo dnf update -y
    sudo dnf install -y ctags \
                        fuse \
                        fuse-libs \
                        gettext gcc make
    # Install the latest version of ripgrep
    LATEST_RG_URL=$(curl -s https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | grep browser_download_url | grep x86_64-unknown-linux-musl.tar.gz | cut -d '"' -f 4)
    LATEST_RG_FILE=$(basename $LATEST_RG_URL)
    curl -LO $LATEST_RG_URL
    tar -xzf $LATEST_RG_FILE
    RG_DIR=$(basename $LATEST_RG_FILE .tar.gz)
    sudo cp $RG_DIR/rg /usr/local/bin/
    rm -rf $RG_DIR $LATEST_RG_FILE
else
    echo "Unsupported OS"
    exit 1
fi

# Install nodejs
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
nvm --version
nvm install 23 
nvm use 23
nvm alias default 23

echo "nvm use 23 > /dev/null" >> ~/.bashrc

source ~/.bashrc

# Install native tree-sitter CLI for Amazon Linux (resolves glibc/npm issues)
if [ "$OS" == "amzn" ]; then
    mkdir -p ~/bin
    curl -sL https://github.com/tree-sitter/tree-sitter/releases/download/v0.22.6/tree-sitter-linux-x64.gz -o ~/bin/tree-sitter.gz
    gzip -df ~/bin/tree-sitter.gz
    chmod +x ~/bin/tree-sitter
    # Add ~/bin to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
    fi
fi

# Clone and build Neovim
git clone https://github.com/neovim/neovim.git
cd neovim/ && make -j $(nproc) CMAKE_BUILD_TYPE=RelWithDebInfo && sudo make install
cd ../ && rm -rf neovim
nvim -v

# Configure Neovim
rm -rf "/home/$(whoami)/.config/nvim"
git clone https://github.com/PrzemyslawSagalo/nvim.git ~/.config/nvim
