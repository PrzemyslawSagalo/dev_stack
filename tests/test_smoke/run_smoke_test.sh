#!/usr/bin/env bash
set -euo pipefail

DISTRO="${1:-ubuntu:22.04}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

case "$DISTRO" in
    ubuntu|ubuntu:22.04)
        IMAGE="ubuntu:22.04"
        ;;
    ubuntu:24.04)
        IMAGE="ubuntu:24.04"
        ;;
    amazonlinux|amazonlinux:2023|amzn|amzn2023)
        IMAGE="amazonlinux:2023"
        ;;
    *)
        IMAGE="$DISTRO"
        ;;
esac

echo "=========================================================="
echo " Starting Smoke Test for: $IMAGE"
echo " Repository root: $REPO_DIR"
echo "=========================================================="

if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker daemon is not running or current user cannot access docker." >&2
    exit 1
fi

CONTAINER_NAME="dev_stack_smoke_${IMAGE//[:\/]/_}_$$"

docker run --rm -t \
    --name "$CONTAINER_NAME" \
    -v "$REPO_DIR:/dev_stack_src:ro" \
    -v "$SCRIPT_DIR/entrypoint.sh:/entrypoint.sh:ro" \
    "$IMAGE" \
    /bin/bash /entrypoint.sh
