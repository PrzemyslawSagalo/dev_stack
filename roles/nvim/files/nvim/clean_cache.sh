#!/bin/bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nvim"

rm -rf "${CACHE_DIR}"
rm -rf "${DATA_DIR}"
rm -rf "${STATE_DIR}"
rm -f "${CONFIG_DIR}/lazy-lock.json"
