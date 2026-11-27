#!/usr/bin/env bats

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    local repo_root
    repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
    export PATH="$HOME/.local/bin:$PATH"
    export PYTHONUSERBASE="${PYTHONUSERBASE:-$HOME/.local}"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    export ANSIBLE_HOME="$BATS_TEST_TMPDIR/.ansible"
    export ANSIBLE_ROLES_PATH="$repo_root/roles"
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/.config"
    unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS
    export GIT_CONFIG_NOSYSTEM=1
    export GIT_CEILING_DIRECTORIES="${BATS_TEST_TMPDIR%/*}"
    export TMPDIR="$BATS_TEST_TMPDIR"

    cat >"$BATS_TEST_TMPDIR/playbook.yml" <<'YAML'
---
- hosts: localhost
  connection: local
  gather_facts: true
  roles:
    - dotfiles
YAML

    cat >"$BATS_TEST_TMPDIR/ansible_prompt.py" <<'PYTHON'
import errno
import os
import pty
import select
import signal
import sys
import termios
import time

pid, fd = pty.fork()
if pid == 0:
    attributes = termios.tcgetattr(0)
    attributes[3] |= termios.ICANON | termios.ECHO
    termios.tcsetattr(0, termios.TCSANOW, attributes)
    os.execvp("ansible-playbook", [
        "ansible-playbook", "-i", "localhost,", sys.argv[1],
        "--start-at-task=Deploy .gitconfig",
        "-e", "ansible_python_interpreter=/usr/bin/python3",
    ])

prompts = [
    (b"Git user.name [press Enter for global default: Przemyslaw Sagalo]", sys.argv[2]),
    (b"Git user.email [press Enter to skip]", sys.argv[3]),
]
pending = b""
deadline = time.monotonic() + 90
try:
    terminal_open = True
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("Ansible timed out")
        ready, _, _ = select.select([fd] if terminal_open else [], [], [], min(remaining, 0.5))
        if ready:
            try:
                data = os.read(fd, 65536)
            except OSError as exc:
                if exc.errno != errno.EIO:
                    raise
                data = b""
            if not data:
                terminal_open = False
            else:
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
                pending += data
                if prompts and prompts[0][0] in pending:
                    prompt, answer = prompts.pop(0)
                    pending = pending.split(prompt, 1)[1]
                    while termios.tcgetattr(fd)[3] & termios.ICANON:
                        if time.monotonic() >= deadline:
                            raise TimeoutError("Ansible did not enter terminal input mode")
                        time.sleep(0.02)
                    time.sleep(0.05)
                    os.write(fd, answer.encode() + b"\r")
        child, status = os.waitpid(pid, os.WNOHANG)
        if child:
            exit_code = os.waitstatus_to_exitcode(status)
            if exit_code:
                sys.exit(exit_code if exit_code > 0 else 128 - exit_code)
            if prompts:
                print("PTY driver: Ansible exited before all prompts", file=sys.stderr)
                sys.exit(1)
            sys.exit(0)
except (OSError, TimeoutError) as exc:
    print(f"PTY driver: {exc}", file=sys.stderr)
    try:
        os.killpg(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    try:
        os.waitpid(pid, 0)
    except ChildProcessError:
        pass
    sys.exit(1)
finally:
    os.close(fd)
PYTHON
}

@test "given missing gitconfig.local and email input, when running dotfiles gitconfig tasks, then gitconfig.local is created and git resolves user.email" {
    run python3 "$BATS_TEST_TMPDIR/ansible_prompt.py" "$BATS_TEST_TMPDIR/playbook.yml" "" "developer@example.com"
    assert_success
    assert_file_exists "$HOME/.gitconfig"
    assert_file_exists "$HOME/.gitconfig.local"
    assert_file_contains "$HOME/.gitconfig.local" '^\[user\]$'
    assert_file_contains "$HOME/.gitconfig.local" 'email = developer@example.com'

    run git -C "$HOME" config user.email
    assert_success
    assert_output "developer@example.com"

    run git -C "$HOME" config user.name
    assert_success
    assert_output "Przemyslaw Sagalo"
}

@test "given missing gitconfig.local and name and email inputs, when running dotfiles gitconfig tasks, then git resolves both custom values" {
    run python3 "$BATS_TEST_TMPDIR/ansible_prompt.py" "$BATS_TEST_TMPDIR/playbook.yml" "Local Developer" "developer@example.com"
    assert_success
    assert_file_contains "$HOME/.gitconfig.local" 'name = Local Developer'
    assert_file_contains "$HOME/.gitconfig.local" 'email = developer@example.com'

    run git -C "$HOME" config user.name
    assert_success
    assert_output "Local Developer"

    run git -C "$HOME" config user.email
    assert_success
    assert_output "developer@example.com"
}

@test "given empty inputs, when running dotfiles gitconfig tasks, then gitconfig.local is not created" {
    run python3 "$BATS_TEST_TMPDIR/ansible_prompt.py" "$BATS_TEST_TMPDIR/playbook.yml" "" ""
    assert_success
    assert_file_not_exists "$HOME/.gitconfig.local"
}

@test "given an existing gitconfig.local, when running dotfiles gitconfig tasks, then existing content is preserved unchanged" {
    printf '[user]\n\tname = Existing User\n\temail = existing@example.com\n# keep this comment\n' >"$HOME/.gitconfig.local"
    cp "$HOME/.gitconfig.local" "$BATS_TEST_TMPDIR/original"

    run timeout 90 ansible-playbook -i localhost, "$BATS_TEST_TMPDIR/playbook.yml" \
        --start-at-task='Deploy .gitconfig' -e ansible_python_interpreter=/usr/bin/python3 </dev/null
    assert_success
    refute_output --partial "Not waiting for response to prompt as stdin is not interactive"
    refute_output --partial "Git user.name [press Enter"
    refute_output --partial "Git user.email [press Enter"
    assert_files_equal "$HOME/.gitconfig.local" "$BATS_TEST_TMPDIR/original"
}

@test "given non-interactive stdin, when running dotfiles gitconfig tasks with missing gitconfig.local, then execution succeeds without creating gitconfig.local" {
    run timeout 90 ansible-playbook -i localhost, "$BATS_TEST_TMPDIR/playbook.yml" \
        --start-at-task='Deploy .gitconfig' -e ansible_python_interpreter=/usr/bin/python3 </dev/null
    assert_success
    assert_output --partial "Not waiting for response to prompt as stdin is not interactive"
    assert_file_not_exists "$HOME/.gitconfig.local"
}
