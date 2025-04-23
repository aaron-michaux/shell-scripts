#!/bin/bash

show_help() {
    cat <<EOF

   Usage: $(basename $0) <dirname>?

EOF
}

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

if (( $# == 1 )) ; then
    [ ! -d "$1" ] && echo "Directory not found: $1" 1>&2 && exit 1
    cd "$1"
fi
           
PPWD="$(pwd -P)"
VENV_DIR="$HOME/Documents/venv"
if [ ! -f "$VENV_DIR/bin/activate" ] ; then
    echo "Creating venv, directory: $VENV_DIR"
    mkdir -p "$VENV_DIR"
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

pip install matplotlib
python3 "$(dirname "$0")/file-sizes-histogram.py"
