#!/bin/sh
set -eu

if [ "${BOOTSTRAP_SOURCE_ONLY:-0}" != "1" ]; then
    if [ -z "${BASH_VERSION:-}" ]; then
        if command -v bash >/dev/null 2>&1; then
            if [ -f "$0" ]; then
                exec bash "$0" "$@"
            fi
        fi
    fi
fi

if [ -n "${BASH_VERSION:-}" ]; then
    set -o pipefail
fi

verify_sudo_access() {
    SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
        if ! command -v sudo >/dev/null 2>&1; then
            echo "Error: 'sudo' command not found. Please install sudo or run as root." >&2
            exit 1
        fi
        SUDO="sudo"
    fi
}

detect_os() {
    OS_ID="unknown"
    OS_ID_LIKE=""
    OS_NAME="Linux"

    OS_RELEASE_FILE="${OS_RELEASE_FILE:-/etc/os-release}"
    if [ -f "$OS_RELEASE_FILE" ]; then
        while IFS='=' read -r key val || [ -n "$key" ]; do
            case "$val" in
                \"*\") val="${val#\"}"; val="${val%\"}" ;;
                \'*\') val="${val#\'}"; val="${val%\'}" ;;
            esac
            case "$key" in
                ID)
                    if [ "$OS_ID" = "unknown" ]; then
                        OS_ID="$val"
                    fi
                    ;;
                ID_LIKE)
                    if [ -z "$OS_ID_LIKE" ]; then
                        OS_ID_LIKE="$val"
                    fi
                    ;;
                NAME)
                    if [ "$OS_NAME" = "Linux" ]; then
                        OS_NAME="$val"
                    fi
                    ;;
            esac
        done < "$OS_RELEASE_FILE"
    fi
}

detect_package_manager() {
    CANDIDATE_FAMILY=""
    case " ${OS_ID:-} ${OS_ID_LIKE:-} " in
        *"ubuntu"*|*"debian"*|*"pop"*|*"mint"*)
            CANDIDATE_FAMILY="debian"
            ;;
        *"amzn"*)
            CANDIDATE_FAMILY="amazon"
            ;;
    esac

    HAS_APT=""
    HAS_DNF=""
    HAS_YUM=""

    command -v apt-get >/dev/null 2>&1 && HAS_APT="1"
    command -v dnf >/dev/null 2>&1 && HAS_DNF="1"
    command -v yum >/dev/null 2>&1 && HAS_YUM="1"

    OS_FAMILY=""
    PKG_MGR=""

    if [ "$CANDIDATE_FAMILY" = "debian" ] && [ -n "$HAS_APT" ]; then
        OS_FAMILY="debian"
        PKG_MGR="apt-get"
    elif [ "$CANDIDATE_FAMILY" = "amazon" ] && { [ -n "$HAS_DNF" ] || [ -n "$HAS_YUM" ]; }; then
        OS_FAMILY="amazon"
        if [ -n "$HAS_DNF" ]; then
            PKG_MGR="dnf"
        else
            PKG_MGR="yum"
        fi
    elif [ -n "$HAS_APT" ] && [ -z "$HAS_DNF" ] && [ -z "$HAS_YUM" ]; then
        OS_FAMILY="debian"
        PKG_MGR="apt-get"
    elif [ -n "$HAS_DNF" ] || [ -n "$HAS_YUM" ]; then
        OS_FAMILY="amazon"
        if [ -n "$HAS_DNF" ]; then
            PKG_MGR="dnf"
        else
            PKG_MGR="yum"
        fi
    else
        echo "Error: Unknown package manager or unsupported distribution '${OS_ID:-unknown}' (${OS_NAME:-Linux})." >&2
        echo "       dev_stack officially supports Ubuntu 22.04+ and Amazon Linux 2023." >&2
        echo "       Script supports package managers: apt-get, dnf, or yum." >&2
        exit 1
    fi
}

install_base_dependencies() {
    if [ "$OS_FAMILY" = "debian" ]; then
        echo "==> Detected Debian/Ubuntu family ($PKG_MGR). Installing base dependencies..."
        $SUDO env DEBIAN_FRONTEND=noninteractive apt-get update
        $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y git make python3 python3-pip sudo bash
    elif [ "$OS_FAMILY" = "amazon" ]; then
        echo "==> Detected Amazon Linux ($PKG_MGR). Installing base dependencies..."
        $SUDO "$PKG_MGR" install -y git make python3 python3-pip sudo bash
    fi
}

install_ansible() {
    if command -v ansible-playbook >/dev/null 2>&1; then
        echo "==> ansible-playbook already installed. Skipping installation."
        return 0
    fi

    echo "==> Resolving Ansible installation..."
    INSTALL_LOG=$(mktemp)

    pkg_prefix="RPM"
    if [ "$OS_FAMILY" = "debian" ]; then
        pkg_prefix="APT"
    fi

    install_cmd="$SUDO $PKG_MGR install -y"
    if [ "$OS_FAMILY" = "debian" ]; then
        install_cmd="$SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y"
    fi

    if $install_cmd ansible >"$INSTALL_LOG" 2>&1; then
        echo "==> Successfully installed ansible meta-package via $PKG_MGR."
        rm -f "$INSTALL_LOG"
    elif $install_cmd ansible-core >"$INSTALL_LOG" 2>&1; then
        echo "==> Successfully installed ansible-core via $PKG_MGR."
        rm -f "$INSTALL_LOG"
    else
        echo "==> $pkg_prefix packages (ansible, ansible-core) unavailable via $PKG_MGR."
        echo "    Details from $PKG_MGR attempt:"
        sed 's/^/    /' "$INSTALL_LOG"
        rm -f "$INSTALL_LOG"
        echo "==> Falling back to python3 -m pip install ansible-core..."
        PIP_BREAK=""
        if python3 -m pip install --help 2>&1 | grep -q -- '--break-system-packages'; then
            PIP_BREAK="--break-system-packages"
        fi
        if [ "$(id -u)" -eq 0 ]; then
            python3 -m pip install $PIP_BREAK --no-cache-dir ansible-core
        else
            python3 -m pip install --user $PIP_BREAK --no-cache-dir ansible-core
        fi
    fi
}

configure_python_path() {
    export PATH="${HOME:-/root}/.local/bin:/usr/local/bin:$PATH"
    hash -r 2>/dev/null || true
}

resolve_workspace() {
    SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd || true)"
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/setup.yml" ] && [ -d "$SCRIPT_DIR/roles/system" ]; then
        echo "==> Detected in-repo workspace via script directory ($SCRIPT_DIR). Bypassing clone..."
        DEST_DIR="$SCRIPT_DIR"
        return 0
    fi

    if [ -f "./setup.yml" ] && [ -d "./roles/system" ]; then
        echo "==> Detected in-repo workspace via current working directory. Bypassing clone..."
        DEST_DIR="$(pwd)"
        return 0
    fi

    REPO_URL="${REPO_URL:-https://github.com/PrzemyslawSagalo/dev_stack.git}"
    DEST_DIR="${HOME:-/root}/.dev_stack"

    echo "==> Cloning fresh repository into $DEST_DIR..."
    rm -rf "$DEST_DIR"
    git config --global --add safe.directory '*' 2>/dev/null || true
    git clone "$REPO_URL" "$DEST_DIR"
}

handover_to_ansible() {
    echo "==> Handing over execution to Ansible..."
    cd "$DEST_DIR"
    make setup
}

main() {
    echo "==> Starting environment initialization (Bootstrap)..."
    verify_sudo_access
    detect_os
    detect_package_manager
    install_base_dependencies
    install_ansible
    configure_python_path
    resolve_workspace
    handover_to_ansible
}

if [ "${BOOTSTRAP_SOURCE_ONLY:-0}" != "1" ]; then
    main "$@"
fi
