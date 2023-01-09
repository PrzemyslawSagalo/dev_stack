#!/bin/bash

# Exit immediately if a pipeline returns a non-zero status.
set -e 

# Pares input flags
# Option descriptions
# n - Your name to put it into git config
# e - Your email to put it into git config
NAME=''
EMAIL=''
while getopts n:e: options
do
    case "${options}" in
        n) NAME=${OPTARG};;
        e) EMAIL=${OPTARG};;
    esac
done
echo "name: $NAME"
echo "email: $EMAIL"

# Crete dir for configs
mkdir -p ~/.config

# Install dev tools
sudo apt update -y 
sudo apt install git \
	         wget \
                 apt-utils \
		 tmux \
		 htop \
		 net-tools \
		 zip \
	         dos2unix -y

# Configure git
git config --global user.name $NAME
git config --global user.email $EMAIL
ssh-keygen -t ed25519 -C $EMAIL

# Install noevim latest
wget https://github.com/neovim/neovim/releases/download/v0.8.0/nvim-linux64.deb
sudo apt install ./nvim-linux64.deb -y
rm -f ./nvim-linux64.deb
nvim -v
## Install packer
rm -rf "/home/$(whoami)/.local/share/nvim/site/pack/packer"
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 		    ~/.local/share/nvim/site/pack/packer/start/packer.nvim
git clone https://github.com/PrzemyslawSagalo/nvim.git\
          ~/.config/nvim
sudo apt update -y
# needed by tagbar extension for neovim
sudo apt instll -y exuberant-ctags \
		   nodejs \
		   npm

# Install docker and docker-compose
sudo apt update -y
sudo apt install docker.io -y
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu

# Install cpp stuff
sudo apt update -y
sudo apt install cmake\
	         build-essential -y
