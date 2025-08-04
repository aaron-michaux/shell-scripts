#!/bin/bash
           
PPWD="$(pwd -P)"
VENV_DIR="$HOME/Documents/venv"
if [ ! -f "$VENV_DIR/bin/activate" ] ; then
    echo "Creating venv, directory: $VENV_DIR"
    mkdir -p "$VENV_DIR"
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

pip install humanfriendly
python3 "$(dirname "$0")/filter-eml-files.py" "$@"
