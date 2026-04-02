#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 FILE DIR" >&2
  exit 1
fi

src="$1"
dest_dir="$2"

# Check source exists
if [[ ! -e "$src" ]]; then
  echo "Error: source '$src' does not exist" >&2
  exit 1
fi

# Check destination is a directory
if [[ ! -d "$dest_dir" ]]; then
  echo "Error: destination '$dest_dir' is not a directory" >&2
  exit 1
fi

base="$(basename -- "$src")"
dest="${dest_dir%/}/$base"

# Prevent overwriting unless you want chaos
if [[ -e "$dest" ]]; then
  echo "Error: destination '$dest' already exists" >&2
  exit 1
fi

# Move the file
mv -- "$src" "$dest"

# Create symlink at old location → new location
ln -s -- "$dest" "$src"
