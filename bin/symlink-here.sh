#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 TARGET" >&2
  exit 1
fi

target="$1"

# Optional sanity check (remove if you want dangling links allowed)
if [[ ! -e "$target" ]]; then
  echo "Warning: target '$target'" >&2
  exit 1
fi

name="$(basename -- "$target")"

if [[ -e "$name" || -L "$name" ]]; then
  echo "Error: '$name' already exists in current directory" >&2
  exit 1
fi

ln -s -- "$target" "$name"
