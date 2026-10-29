#!/bin/bash
# tests/test_helpers.sh - Shared test harness and mock primitives

# 1. Include guard
[ -n "${_DEV_STACK_TEST_HELPERS_SH:-}" ] && return 0
export _DEV_STACK_TEST_HELPERS_SH=1

# 2. Common paths derivation
if [ -n "${BASH_VERSION:-}" ]; then
    eval '_SRC="${BASH_SOURCE[0]}"'
    REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$_SRC")/.." 2>/dev/null && pwd || pwd)}"
else
    REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd || pwd)}"
fi
BOOTSTRAP_SCRIPT="${BOOTSTRAP_SCRIPT:-$REPO_ROOT/bootstrap.sh}"

# 3. Test harness state
TEST_COUNT=${TEST_COUNT:-0}
PASS_COUNT=${PASS_COUNT:-0}

# 4. run_test <test_name> <cmd...>
run_test() {
    local test_name="$1"
    shift
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "========================================"
    echo "Running Test ${TEST_COUNT}: ${test_name}"
    echo "========================================"
    if "$@"; then
        echo "PASS: Test ${TEST_COUNT} - ${test_name}"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo "FAIL: Test ${TEST_COUNT} - ${test_name}" >&2
        return 1
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

# 6. Semantic mock wrappers
mock_sudo() {
    local bin_dir="$1"
    create_mock "$bin_dir" "sudo" 'exec "$@"'
}

mock_make() {
    local bin_dir="$1"
    local record_pwd="${2:-true}"
    if [ "$record_pwd" = "true" ]; then
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
    local tools="bash dirname basename uname cut sed grep awk date echo cat mkdir rm mktemp which id env chmod tr"
    local cmd target
    for cmd in $tools; do
        if [ ! -e "$bin_dir/$cmd" ] && [ ! -L "$bin_dir/$cmd" ]; then
            target="$(command -v "$cmd" 2>/dev/null || true)"
            if [ -n "$target" ] && [ -x "$target" ]; then
                ln -s "$target" "$bin_dir/$cmd"
            fi
        fi
    done
}

# 8. Fixture workspace generators
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
