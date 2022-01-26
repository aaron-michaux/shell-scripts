#!/bin/bash

REMOTE="dev"
SRCD="$HOME/Projects/shell-scripts"
DSTD="/home/BRCMLTD/am894222/Bin/shell-scripts"

sync_files()
{
    rsync -azvcth --no-times             \
          --exclude ".git"               \
          --exclude "*/.git"             \
          --exclude ".github"            \
          --exclude "*/.github"          \
          $SRCD/ dev:$DSTD               \
          --delete-after
}

sync_files


