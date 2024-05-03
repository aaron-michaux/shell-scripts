#!/bin/bash

set -eou pipefail

show_help()
{
    cat <<EOF

   Usage: $(basename $0) 

   Options:

      -l|--list       List all backups
      -r|--restore    Restore the latest backup

EOF
}

HACK_DIR="$HOME/Fun/nethack/games"
SAVE_DIR="$HACK_DIR/lib/nethackdir/save"
BACK_DIR="$HACK_DIR/backup"

USER="SongTurtle"
FILE="1000${USER}.gz"
HACK="$HACK_DIR/nethack"
SAVE="$SAVE_DIR/$FILE"

DO_EXEC="True"
DO_LIST="False"
DO_RESTORE="False"
DO_RESTORE_NUM=""

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "-l" ] || [ "$ARG" = "--list" ] && DO_LIST="True" && DO_EXEC="False" && continue
    if [ "$ARG" = "-r" ] || [ "$ARG" = "--restore" ] ; then
        DO_RESTORE="True"
        if (( $# > 0 )) ; then
            if [ "$1" -eq "$1" 2>/dev/null ] || [ "$1" = "restore" ] ; then
                DO_RESTORE_NUM="$1"
                shift
            fi
        fi
        continue
    fi

    echo "Unexpected argument: $ARG, aborting" 1>&2
    exit 1
done

do_listing()
{
    while read FILE ; do
        echo "$(date "+%Y-%m-%d %H:%M:%S" -r "$FILE")  $FILE"
    done < <(find "$BACK_DIR" -type f) | sort
}

last_file()
{
    do_listing | tail -n 1 | awk '{ print $3 }'
}

file_hash()
{
    if [ -f "$1" ] ; then
        sha256sum "$1" | awk '{ print $1 }'
    else
        echo
    fi
}

do_backup()
{
    # Make the backup
    if [ ! -f "$SAVE" ] ; then
        echo "Failed to find save file: '$SAVE'"
    else
        LAST_FILE="$(last_file)"
        if [ "$(file_hash "$LAST_FILE")" = "$(file_hash "$SAVE")" ] ; then
            echo "already backed up, save-file: $SAVE == $LAST_FILE"
            return 0
        fi
        
        COUNTER="$(find "$BACK_DIR" -type f | wc -l)"
        while (( 1 )) ; do
            FILE="$BACK_DIR/$FILE.$COUNTER"
            if [ -f "$FILE" ] ; then
                COUNTER="$(expr $COUNTER + 1)"
                continue
            fi
            echo "cp '$SAVE' '$FILE'"
            cp "$SAVE" "$FILE"
            break
        done
    fi
}

do_restore()
{
    if [ "$DO_RESTORE_NUM" = "" ] ; then
        RESTORE_FILE="$(last_file)"
    else
        RESTORE_FILE="$BACK_DIR/$FILE.$DO_RESTORE_NUM"
    fi
    if [ ! -f "$RESTORE_FILE" ] ; then
        echo "restore file not found: $RESTORE_FILE"
        exit 1
    fi
    
    if [ -f "$RESTORE_FILE" ] ; then
        if [ -f "$SAVE" ] ; then
            echo cp "$SAVE" "$BACK_DIR/$FILE.restore"
            cp "$SAVE" "$BACK_DIR/$FILE.restore"
        fi
        echo cp "$RESTORE_FILE" "$SAVE"
        cp "$RESTORE_FILE" "$SAVE"
    fi
}

mkdir -p "$BACK_DIR"

# Listing
if [ "$DO_LIST" = "True" ] ; then
    do_listing
fi

# Boot nethack
if [ "$DO_EXEC" = "True" ] ; then
    if [ "$DO_RESTORE" = "True" ] ; then
        do_restore
    else
        do_backup
    fi
    echo "$HACK"
    "$HACK"
fi

