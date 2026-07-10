#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="${1:-$PWD}"
PROJECT_DIR="$(realpath "$PROJECT_DIR")"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/opencode"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/opencode"

OPENCODE_HOME=/home/opencode

mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR"
mkdir -p "/tmp/opencode/tmp"
mkdir -p "/tmp/opencode/$OPENCODE_HOME"
mkdir -p "$HOME/.opencode"

exec docker run --rm -it \
    --user "$(id -u):$(id -g)" \
    --cap-drop=ALL \
    --security-opt=no-new-privileges:true \
    --pids-limit=512 \
    --memory=8g \
    --cpus=12 \
    --read-only \
    -e HOME=$OPENCODE_HOME \
    -v "/tmp/opencode/tmp:/tmp:rw" \
    -v "/tmp/opencode/$OPENCODE_HOME:$OPENCODE_HOME:rw" \
    -v "$HOME/.opencode:$OPENCODE_HOME/.opencode:rw" \
    -v "$HOME/.config/opencode:$OPENCODE_HOME/.config/opencode:rw" \
    -v "$HOME/.local/share:$OPENCODE_HOME/.local/share:rw" \
    -v "$HOME/.cache/opencode:$OPENCODE_HOME/.cache/opencode:rw" \
    -v "$PROJECT_DIR:/workspace:rw" \
    -w /workspace \
    opencode-sandbox

