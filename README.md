# Dev Stack

Automated, reproducible, and tested Linux development environment provisioning using Ansible.

Supports modern Linux distributions including **Ubuntu 22.04+**, **Amazon Linux 2023**, and **Red Hat Enterprise Linux / UBI 9**.

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

The repository provides [Makefile](file:///home/ec2-user/src/dev_stack/Makefile) targets for common tasks:

```bash
make setup   # Provisions or re-applies the environment via local Ansible
make update  # Pulls latest main branch and re-runs the Ansible playbook
make test    # Runs Molecule acceptance tests across container platforms
make lint    # Runs pre-commit and ansible-lint code quality checks
```

### 3. Direct Ansible Execution

To run or re-apply the playbook directly:

```bash
ansible-playbook -i localhost, -c local setup.yml
```

---

## What Gets Configured

`dev_stack` provisions the workstation declaratively via modular Ansible roles in [setup.yml](file:///home/ec2-user/src/dev_stack/setup.yml):

* **System Tools & Runtimes (`roles/system`)**:
  * **Python**: `pyenv` with Python 3.13 default, Python 3.12, pre-compiled C-extension build dependencies (`ssl`, `sqlite3`, `lzma`, `ctypes`), and shims across login/interactive shells.
  * **Docker**: Docker CE engine with rootless group access, Docker Compose v2 CLI plugin, and virtualization-aware daemon management.
  * **Languages & Cloud Tools**: OpenJDK / Amazon Corretto 21 with SDKMAN, Node.js via `nvm`, Helm, and OpenShift client (`oc`).
  * **Core CLI Packages**: `git`, `tmux`, `jq`, `unzip`, `curl`, `wget`, `htop`, `try`.
* **Dotfiles & Shell (`roles/dotfiles`)**:
  * Comprehensive `.bash_aliases` suite (Git shortcuts, tmux helpers, Python venv macros, environment loaders).
  * Terminal multiplexer configuration (`.tmux.conf`) with vi-mode navigation.
  * SSH client configuration (`~/.ssh/config`).
  * AI assistant configurations (`.config/copilot`, `.config/claude`).
* **Editor (`roles/nvim`)**:
  * Modern Neovim IDE configuration.
