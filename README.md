# Dev Stack

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Automated, reproducible, and tested Linux development environment provisioning using Ansible.

Supports modern Linux distributions including **Ubuntu 22.04+** and **Amazon Linux 2023**.

---

## Quick Start

### 1. Fresh Machine Bootstrap (Zero Manual Setup)

On a clean Linux workstation or AWS EC2 instance:

```bash
curl -fsSL https://raw.githubusercontent.com/PrzemyslawSagalo/dev_stack/main/bootstrap.sh | bash
```

Alternatively, if you already cloned the repository:

```bash
chmod +x bootstrap.sh
./bootstrap.sh
```

### 2. Operational Shortcuts (Makefile)

The repository provides a [Makefile](Makefile) for managing common workflows. Run `make help` to view all available commands:

```bash
make help
```

### 3. Direct Ansible Execution

To run or re-apply the playbook directly:

```bash
ansible-playbook setup.yml
```

---

## What Gets Configured

`dev_stack` provisions the workstation declaratively via modular Ansible roles in [setup.yml](setup.yml):

* **System Tools & Runtimes (`roles/system`)**:
  * **Python**: `pyenv` with Python 3.13 default, Python 3.12, Python 3.11, pre-compiled C-extension build dependencies (`ssl`, `sqlite3`, `lzma`, `ctypes`), and shims across login/interactive shells.
  * **C++**: GCC, G++, Clang, Make, and CMake build toolchain.
  * **Docker**: Docker CE engine with rootless group access, Docker Compose v2 CLI plugin, and virtualization-aware daemon management.
  * **Languages & Cloud Tools**: OpenJDK / Amazon Corretto 21 with SDKMAN, Node.js via `nvm`, Go toolchain, Helm, OpenShift client (`oc`), AWS CLI v2, and GitHub CLI (`gh`).
  * **Core CLI Packages**: `git`, `tmux`, `jq`, `ripgrep`, `tree-sitter`, `lazygit`, `unzip`, `curl`, `wget`, `htop`, `try`, `agy` (Google Antigravity CLI).
* **Dotfiles & Shell (`roles/dotfiles`)**:
  * Comprehensive `.bash_aliases` suite (Git shortcuts, tmux helpers, Python venv macros, environment loaders).
  * Terminal multiplexer configuration (`.tmux.conf`) with vi-mode navigation.
  * SSH client configuration (`~/.ssh/config`).
  * Git global configuration (`~/.gitconfig`).
  * AI assistant configuration (`.config/copilot`).
* **Editor (`roles/nvim`)**:
  * Modern Neovim IDE configuration.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
