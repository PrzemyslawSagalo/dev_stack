#!/bin/bash

EMAIL="przemyslaw.sagalo@gmail.com"

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
git config --global user.name "Przemyslaw Sagalo"
git config --global user.email $EMAIL
ssh-keygen -t ed25519 -C EMAIL

# Install noevim latest
wget https://github.com/neovim/neovim/releases/download/v0.8.0/nvim-linux64.deb
sudo apt install ./nvim-linux64.deb -y
rm -f ./nvim-linux64.deb
nvim -v
## Install packer
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim

# Install docker and docker-compose
sudo apt update -y && sudo apt install docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu

# Install cpp stuff
sudo apt update -y
sudo apt install cmake\
	         build-essential -y
