#!/bin/bash

REMOTE="dev"
SRCD="$HOME/Development/SWG_NGP_kestrel"
DSTD="/home/BRCMLTD/am894222/sync/SWG_NGP_kestrel"
PID1=
PID2=

trap cleanup EXIT
cleanup()
{
    [ "$PID1" != "" ] && kill $PID1
    [ "$PID2" != "" ] && kill $PID2
}

# -------------------------------------------------------------------- show-help

show_help()
{
    cat <<EOF

   Usage: $(basename $0) [OPTIONS...]

      --forever   
      --all
      --git
      --git-only

EOF
}

# ----------------------------------------------------------------- command-line

FOREVER=0
ALL=0
GIT=0
GIT_ONLY=0
while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
    [ "$ARG" = "--forever" ] && FOREVER=1 && continue
    [ "$ARG" = "--all" ] && ALL=1 && continue
    [ "$ARG" = "--git" ] && GIT=1 && continue
    [ "$ARG" = "--git-only" ] && GIT_ONLY=1 && GIT=1 && continue
    echo "Unexpected argument: '$ARG'" 1>&2
    exit 1
done

# ---------------------------------------------------------------------- do-sync

sync_files()
{
    cp "$(which zz-run-twisted.sh)" "$SRCD/"
    rsync -azvcth --no-times             \
          --exclude "bazel*"             \
          --exclude ".git"               \
          --exclude "*/.git"             \
          --exclude ".github"            \
          --exclude "*/.github"          \
          --exclude "*/__pycache__"      \
          --exclude ".tests_to_run"      \
          --exclude "test/cfs"           \
          --exclude "*.DS_Store"         \
          --exclude "envoy"              \
          --exclude "grpc_cple_service"  \
          --exclude "grpc_isolation_async_policy_service" \
          --exclude "packet_toolkit"     \
          --exclude "sslx"               \
          $SRCD/ dev:$DSTD               \
          --delete-after
}

sync_git()
{
    rsync -azvcth --no-times "$SRCD/.git/" "dev:$DSTD/.git" --delete-after
}

do_sync()
{
    if [ "$ALL" = "1" ] ; then
        sync_files
        sync_git
        return 0
    fi
    if [ "$GIT_ONLY" = "0" ] ; then
        sync_files
    fi
    if [ "$GIT" = "1" ] ; then
        sync_git
    fi
}

# ------------------------------------------------------------------------ files

files()
{
    echo "$SRCD/Makefile"
    cp "$(which zz-run-twisted.sh)" "$SRCD/"
    echo "$SRCD/zz-run-twisted.sh"
    find "$SRCD/cfs/test" "$SRCD/test" -type f | grep -v -e "#" | sort
}

calc_md5()
{
    cat $(files) | md5
}

git_md5()
{
    find "$SRCD/.git" -type f -exec cat {} \; | md5
}

sync_forever()
{
    CURRENT_MD5=""
    while true ; do
        NEW_MD5="$(calc_md5)"
        if [ "$CURRENT_MD5" != "$NEW_MD5" ] ; then
            echo "cfs: MD5 => $NEW_MD5"
            CURRENT_MD5="$NEW_MD5"
            do_sync
            echo
            echo
        fi
        sleep 1
    done
}

git_sync()
{
    GIT_MD5=""
    while true ; do
        GIT_NEW_MD5="$(git_md5)"
        if [ "$GIT_MD5" != "$GIT_NEW_MD5" ] ; then
            echo "git: MD5 => $GIT_NEW_MD5"
            GIT_MD5="$GIT_NEW_MD5"
            rsync -azvcth "$SRCD/.git/" "dev:$DSTD/.git" 
            echo
            echo
        fi
        sleep 10
    done
}

# ---------------------------------------------------------------------- Action!

if [ "$FOREVER" = "0" ] ; then
    do_sync
    exit $?
fi

sync_forever &
PID1=$!
# git_sync &

wait

