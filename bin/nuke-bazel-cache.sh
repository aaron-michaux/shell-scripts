#!/bin/bash

CACHE_DIR="$HOME/.cache/bazel"

if [ ! -d "$CACHE_DIR" ] ; then
    exit 0
fi

echo
printf "%s\n" "   🧨🧨🧨 Nuking the contents of $CACHE_DIR 🧨🧨🧨"

run_nuke() {
    cd "$CACHE_DIR"
    TMPD="$(mktemp -d "zzz-cache-delete.XXXXXX")"
    find . -maxdepth 1 -type d | sort | grep -Ev "^\.$" | grep -v "$TMPD" | while read D ; do
        mv -v "$D" "$TMPD/"
    done
    sudo rm -rf "$TMPD"
}

run_nuke 1>/dev/null 2>/dev/null
