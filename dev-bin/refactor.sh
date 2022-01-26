#!/bin/bash

show_help()
{
    cat <<EOF

   Usage: $(basename $0) <OPTIONS...>

      -d <dirname>   The directory tree to refactor in... defaults to \$(pwd)
      -i <pattern>   Input pattern to use
      -o <pattern>   Output pattern to use
      --dry-run      Output changes

EOF
}

DIR="$(pwd)"
IN_PATTERN=""
OUT_PATTERN=""
DRY_RUN=false

while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
    [ "$ARG" = "-i" ] && shift && IN_PATTERN="$1" && continue
    [ "$ARG" = "-o" ] && shift && OUT_PATTERN="$1" && continue
    [ "$ARG" = "--dry-run" ] && DRY_RUN=true && continue

    echo "Unexpected argument: '$ARG', aborting" 1>&2
    exit 1
done

# --------------------------------------------------------------------------------------------------
# Make sure the user knows what they're doing

if [ "$DRY_RUN" != "true" ] ; then
    while true; do
        cat <<EOF

   DIR      $DIR
   IN       $IN_PATTERN
   OUT      $OUT_PATTERN    
   DRY_RUN  $DRY_RUN

EOF
        read -p "Is this correct?" yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi
           
# --------------------------------------------------------------------------------------------------
# ACTION!

# Which sed to use?
which gsed 1>/dev/null 2>/dev/null && SED=gsed || SED=sed

cd "$DIR"
find . -type f | while read FILE ; do
    cat "$FILE" | grep -q "$IN_PATTERN" && HAS=1 || HAS=0
    [ "$HAS" = "0" ] && continue

    echo "Patching: $FILE"
    if [ "$DRY_RUN" = "true" ] ; then
        cat "$FILE" | grep "$IN_PATTERN" | while read LINE ; do
            grep -n "$IN_PATTERN"
            echo " ==> "
            echo "$LINE" | $SED "s,$IN_PATTERN,$OUT_PATTERN,g"
        done | $SED 's,^,   ,'
        echo
    else
        $SED -i "s,$IN_PATTERN,$OUT_PATTERN,g" "$FILE"
    fi
done


