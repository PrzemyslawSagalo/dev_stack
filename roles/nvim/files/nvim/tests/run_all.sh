#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

cd "${CONFIG_DIR}"

FAILURES=0

for test_file in "${SCRIPT_DIR}"/test_*.lua; do
    [ -f "$test_file" ] || continue
    rel_file="tests/$(basename "$test_file")"
    echo "Running $rel_file..."
    if ! nvim --headless -c "lua dofile('$rel_file')" -c "q"; then
        echo "FAIL: $rel_file"
        FAILURES=$((FAILURES+1))
    fi
done

if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES tests failed"
    exit 1
else
    echo "All tests passed successfully"
    exit 0
fi
