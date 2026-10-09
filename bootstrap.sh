#!/bin/bash
set -euo pipefail

echo "==> Rozpoczęcie inicjalizacji środowiska (Bootstrap)..."

# Wykrywanie menedżera pakietów
if command -v apt-get >/dev/null 2>&1; then
    echo "==> Wykryto system z rodziny Debian/Ubuntu. Instalacja Git i Ansible..."
    sudo apt-get update
    sudo apt-get install -y git ansible make
elif command -v yum >/dev/null 2>&1; then
    echo "==> Wykryto system z rodziny RHEL/Amazon Linux. Instalacja Git i Ansible..."
    sudo yum install -y git ansible make
else
    echo "Nieznany menedżer pakietów. Skrypt obsługuje apt-get i yum."
    exit 1
fi

REPO_URL="https://github.com/PrzemyslawSagalo/dev_stack.git"
DEST_DIR="$HOME/.dev_env"

if [ ! -d "$DEST_DIR" ]; then
    echo "==> Klonowanie repozytorium..."
    git clone "$REPO_URL" "$DEST_DIR"
else
    echo "==> Repozytorium już istnieje. Aktualizowanie..."
    cd "$DEST_DIR"
    git pull origin main
fi

echo "==> Przekazywanie kontroli do Ansible..."
cd "$DEST_DIR"
make setup
