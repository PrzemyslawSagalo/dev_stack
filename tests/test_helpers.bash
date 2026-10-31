#!/usr/bin/env bash
# shellcheck shell=bash
# tests/test_helpers.bash - Shared BATS test harness and mock primitives

# 2. Common paths derivation
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    _DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
    REPO_ROOT="${REPO_ROOT:-$(cd "$_DIR/.." >/dev/null 2>&1 && pwd)}"
else
    REPO_ROOT="${REPO_ROOT:-$(pwd)}"
fi
export REPO_ROOT
BOOTSTRAP_SCRIPT="${BOOTSTRAP_SCRIPT:-$REPO_ROOT/bootstrap.sh}"
export BOOTSTRAP_SCRIPT

# 3. Dynamic BATS Library Resolver (bats-support / bats-assert)
load_bats_lib() {
    local lib="$1"
    # Try native bats_load_library_safe if available
    if command -v bats_load_library_safe >/dev/null 2>&1; then
        if bats_load_library_safe "$lib" 2>/dev/null; then
            return 0
        fi
    fi

    # Search candidates across BATS_LIB_PATH, repo-local tests/libs, and system paths
    local candidates=()
    if [ -n "${BATS_LIB_PATH:-}" ]; then
        local IFS=':'
        for p in $BATS_LIB_PATH; do
            candidates+=("$p/$lib/load.bash" "$p/bats-$lib/load.bash")
        done
    fi
    candidates+=(
        "${REPO_ROOT}/tests/libs/${lib}/load.bash"
        "${REPO_ROOT}/tests/libs/bats-${lib}/load.bash"
        "/usr/lib/${lib}/load.bash"
        "/usr/lib/bats-${lib}/load.bash"
        "/usr/lib/bats/${lib}/load.bash"
        "/usr/lib/bats/bats-${lib}/load.bash"
        "/usr/local/lib/${lib}/load.bash"
        "/usr/local/lib/bats-${lib}/load.bash"
        "/usr/local/lib/bats/${lib}/load.bash"
        "/usr/local/lib/bats/bats-${lib}/load.bash"
    )

    for candidate in "${candidates[@]}"; do
        if [ -f "$candidate" ]; then
            # shellcheck disable=SC1090
            source "$candidate"
            return 0
        fi
    done

    return 1
}

# Attempt loading helper libraries if running inside bats
if command -v bats_internal_load >/dev/null 2>&1 || command -v load >/dev/null 2>&1; then
    if ! load_bats_lib bats-support || ! load_bats_lib bats-assert; then
        echo "Error: bats-support or bats-assert not found. Run 'make deps-bats' or install them." >&2
        return 1
    fi
fi

# 4. PATH Isolation Lifecycle Hooks
test_setup() {
    ORIG_PATH="$PATH"
    export ORIG_PATH
}

test_teardown() {
    if [ -n "${ORIG_PATH:-}" ]; then
        PATH="$ORIG_PATH"
        export PATH
    fi
}

# 5. create_mock <bin_dir> <cmd_name> [body | -]
create_mock() {
    local bin_dir="$1"
    local cmd_name="$2"
    local body=""

    if [ "$#" -ge 3 ]; then
        if [ "$3" = "-" ]; then
            body="$(cat)"
        else
            body="$3"
        fi
    else
        body="exit 0"
    fi

    mkdir -p "$bin_dir"
    local target="$bin_dir/$cmd_name"

    case "$body" in
        "#!"*)
            printf "%s\n" "$body" > "$target"
            ;;
        *)
            printf "#!/bin/sh\n%s\n" "$body" > "$target"
            ;;
    esac
    chmod +x "$target"
}

# 6. Semantic Mock Wrappers
mock_sudo() {
    local bin_dir="$1"
    create_mock "$bin_dir" "sudo" 'exec "$@"'
}

mock_make() {
    local bin_dir="$1"
    local record_pwd="${2:-true}"
    if [ "$record_pwd" = "true" ]; then
        # shellcheck disable=SC2016
        create_mock "$bin_dir" "make" 'echo "MAKE_PWD=$PWD"
exit 0'
    else
        create_mock "$bin_dir" "make" 'exit 0'
    fi
}

mock_ansible_playbook() {
    local bin_dir="$1"
    create_mock "$bin_dir" "ansible-playbook" 'exit 0'
}

mock_pkg_mgr() {
    local bin_dir="$1"
    local mgr_name="$2"
    local mode="${3:-stub}"

    local log_tag
    case "$mgr_name" in
        apt-get|apt) log_tag="APT" ;;
        dnf)         log_tag="DNF" ;;
        microdnf)    log_tag="MICRODNF" ;;
        yum)         log_tag="YUM" ;;
        *)           log_tag="$(echo "$mgr_name" | tr '[:lower:]' '[:upper:]')" ;;
    esac

    case "$mode" in
        stub)
            create_mock "$bin_dir" "$mgr_name" 'exit 0'
            ;;
        log)
            create_mock "$bin_dir" "$mgr_name" "echo \"${log_tag}_CALLED: \$*\"
exit 0"
            ;;
        fail-ansible)
            create_mock "$bin_dir" "$mgr_name" "if [ \"\$1\" = \"install\" ]; then
    case \" \$* \" in
        *\" ansible \"*|*\" ansible-core \"*|*\"ansible\"*|*\"ansible-core\"*)
            exit 1
            ;;
    esac
fi
echo \"${log_tag}_CALLED: \$*\"
exit 0"
            ;;
        *)
            echo "Unknown mode for mock_pkg_mgr: $mode" >&2
            return 1
            ;;
    esac
}

mock_microdnf() {
    local bin_dir="$1"
    create_mock "$bin_dir" "microdnf" "echo \"MICRODNF_CALLED: \$*\"
dir=\$(dirname \"\$0\")
cat << 'EOF' > \"\$dir/dnf\"
#!/bin/sh
exit 0
EOF
chmod +x \"\$dir/dnf\"
exit 0"
}

# 7. link_coreutils <bin_dir>
link_coreutils() {
    local bin_dir="$1"
    mkdir -p "$bin_dir"
    local tools=(bash dirname basename uname cut sed grep awk date echo cat mkdir rm mktemp which id env chmod tr)
    local cmd target
    for cmd in "${tools[@]}"; do
        if [ ! -e "$bin_dir/$cmd" ] && [ ! -L "$bin_dir/$cmd" ]; then
            target="$(command -v "$cmd" 2>/dev/null || true)"
            if [ -n "$target" ] && [ -x "$target" ]; then
                ln -s "$target" "$bin_dir/$cmd"
            fi
        fi
    done
}

# 8. Fixture Workspace Generators
setup_repo_workspace() {
    local ws="$1"
    mkdir -p "$ws/roles/system" "$ws/mock_bin"

    cat << 'EOF' > "$ws/setup.yml"
---
- name: Setup playbook
  hosts: localhost
  connection: local
  tasks:
    - name: Ping
      ansible.builtin.ping:
EOF

    printf 'setup:\n\t@echo "SETUP_SUCCESS"\n' > "$ws/Makefile"
}

setup_container_workspace() {
    local ws="$1"
    local extra_cmds="${2:-}"
    local tab
    tab="$(printf '\t')"
    mkdir -p "$ws/roles/system"

    cat << 'EOF' > "$ws/setup.yml"
---
- name: Smoke test playbook
  hosts: localhost
  connection: local
  tasks:
    - name: Ping
      ansible.builtin.ping:
EOF

    {
        printf 'setup:\n'
        printf '\t@echo "==> MOCK_MAKE_SETUP_START"\n'
        printf '\tcommand -v sudo\n'
        printf '\tansible-playbook --version\n'
        if [ -n "$extra_cmds" ]; then
            printf '%s\n' "$extra_cmds" | while IFS= read -r line || [ -n "$line" ]; do
                case "$line" in
                    "$tab"*)
                        printf '%s\n' "$line"
                        ;;
                    *)
                        printf '\t%s\n' "$line"
                        ;;
                esac
            done
        fi
        printf '\t@echo "==> MOCK_MAKE_SETUP_SUCCESS"\n'
    } > "$ws/Makefile"
}
