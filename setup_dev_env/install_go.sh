#!/bin/bash

sudo apt update -y 

wget https://go.dev/dl/go1.20.6.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go*.tar.gz
export PATH=$PATH:/usr/local/go/bin

go version
