# Install the same stuff as in Anaconda but for free
1. Go to: https://conda-forge.org/download/
1. Copy one of the installation linnke e.g.: https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
1. `culr -L -o Miniforge3-Linux-x86_64.sh https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh`
1. `chmod 770 Miniforge3-Linux-x86_64.sh && ./Miniforge3-Linux-x86_64.sh`
1. `mamba config get channels` - and remove everythiongn except `conda-forge`
