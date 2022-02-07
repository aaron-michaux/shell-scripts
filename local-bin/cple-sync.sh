#!/bin/bash

REMOTE="dev"
LOCALD="$HOME/Development/cple"
REMOTED="dev:/home/BRCMLTD/am894222/Development/scorpius/project/cple/sg_cple1/cple"
REVERSE=false
DRY_RUN=""

if [ "$(hostname)" != "DWH7Y69M2G" ] ; then
    echo "Must run on hostname=\"DWH7Y69M2G\"; however, hostname=\"$(hostname)\"" 1>&2
    exit 1
fi

mkdir -p "$LOCALD"

while true; do
    if [ "$REVERSE" = false ] ; then
        read -p "push CPLE local => remote-dev? " yn
    else
        read -p "pull remove-dev => CPLE local? " yn
    fi
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        [Rr]* )
            REVERSE=true
            ;;
        [Dd]* )
            echo "Setting --dry-run"
            DRY_RUN=--dry-run
            ;;
        * ) echo "Please answer yes or no.";;
    esac
done

SRCD="$LOCALD"
DSTD="$REMOTED"
EXTRA_EXCLUDES="--exclude SWG_NGP_grpc_cple_service --exclude WSS_MDS_API --exclude WSS-CMS-GRPC-API"

if [ "$REVERSE" = "true" ] ; then
    SRCD="$REMOTED"
    DSTD="$LOCALD"
    EXTRA_EXCLUDES=""
fi

sync_files()
{
    rsync -azvcth --no-times $DRY_RUN             \
          --exclude "bazel*"                      \
          --exclude ".git"                        \
          --exclude "*/.git"                      \
          --exclude ".github"                     \
          --exclude "*/.github"                   \
          --exclude "*/__pycache__"               \
          --exclude "*.DS_Store"                  \
          --exclude "zz-run.sh"                   \
          $EXTRA_EXCLUDES                         \
          --exclude "test/BUILD"                  \
          --exclude "NOTES.md"                    \
          $SRCD/ $DSTD                            \
          --delete-after
}

sync_files
