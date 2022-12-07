#!/bin/bash

# Install ansible
#sudo apt-add-repository ppa:ansible/ansible -y && sudo apt update -y
#sudo apt install ansible -y

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

## Install noevim latest
wget https://github.com/neovim/neovim/releases/download/v0.8.0/nvim-linux64.deb
sudo apt install ./nvim-linux64.deb -y
rm -f ./nvim-linux64.deb
nvim -v

## Install docker and docker-compose
sudo apt update -y && sudo apt install docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu

# Install cpp stuff
sudo apt update -y
sudo apt install cmake\
	         build-essential -y

