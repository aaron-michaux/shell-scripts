#!/bin/bash

set -eu

PPWD="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." ; pwd -P)"
TMPD=$(mktemp -d "/tmp/$(basename "$0").XXXXXX")

trap cleanup EXIT
cleanup() {
    rm -rf "$TMPD"
}

show_help() {
    cat <<EOF

    Usage: $(basename "$0") [OPTIONS...]

    Options:

      -i <movie-filename>
      -o <image-filename>
      -n <count>
      --size <widthxheight>

EOF
}

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

INPUT_FILENAME=""
OUT_FILENAME=""
ONEPOS=""
COUNT=1
SIZE=320x280
while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "-i" ] && INPUT_FILENAME="$1" && shift && continue
    [ "$ARG" = "-o" ] && OUT_FILENAME="$1" && shift && continue
    [ "$ARG" = "-n" ] && COUNT="$1" && shift && continue
    [ "$ARG" = "-p" ] && ONEPOS="$1" && shift && continue
    [ "$ARG" = "--size" ] && SIZE="$1" && shift && continue
    echo "Unknown argument: $ARG" 1>&2
    exit 1
done

[ "$INPUT_FILENAME" = "" ] && echo "no input file, aborting" 1>&2 && exit 1
[ "$OUT_FILENAME" = "" ] && echo "no output file, aborting" 1>&2 && exit 1

absfilename()
{
    local FILENAME="$1"
    if [ "${FILENAME:0:1}" = "/" ] ; then
        echo "$FILENAME"
        return 0
    fi
    echo "$(cd "$(dirname "$FILENAME")"; pwd -P)/$(basename "$FILENAME")"
}

cached_info()
{
    local FILENAME="$1"
    local DATAF="$TMPD/$FILENAME._ci"    
    if [ ! -f "$DATAF" ] ; then
        mkdir -p "$(dirname "$DATAF")"
        transcode.sh -i "$FILENAME" --info >> "$DATAF" || IS_MOVIE="False"
    fi
    cat "$DATAF"
}

probe_info()
{
    local FILENAME="$1"
    cached_info "$FILENAME"
}

calc_width()
{
    local F="$1"
    probe_info "$F" | grep -E "^width" | awk -F= '{ print $2 }'
}

calc_height()
{
    local F="$1"
    probe_info "$F" | grep -E "^height" | awk -F= '{ print $2 }'
}

# Convert a timestamp to seconds
to_seconds()
{
    local TS="$1"
    H="$(echo "$TS" | awk -F: '{ print $1 }')"
    M="$(echo "$TS" | awk -F: '{ print $2 }')"
    S="$(echo "$TS" | awk -F: '{ print $3 }' | awk -F. '{ print $1 }')"
    echo "$H * 3600 + $M * 60 + $S" | bc    
}

calc_duration()
{
    local F="$1"
    local DURATION="$(probe_info "$F" | grep -E "^duration" | awk -F= '{ print $2 }')"
    to_seconds "$(echo "$DURATION" | awk -F. '{ print $1 }')"
}

calc_one_part()
{
    local SECONDS="$1"
    local POS="$2"
    local COUNT="$3"
    local CMD="scale=3 ; ($POS + 1.0) * $SECONDS / ($COUNT + 1.0)"
    local FRAC="$(echo "$CMD" | bc)"
    #echo $CMD
    echo $FRAC
}

calc_parts()
{
    local SECONDS="$1"
    local COUNT="$2"
    I=0
    while (( $I < $COUNT )) ; do
        calc_one_part "$SECONDS" "$I" "$COUNT"
        I=$(expr $I + 1)
    done | tr '\n' ' '
}

to_ss()
{
    local IN="$1"
    FULLS="$(echo "$IN" | awk -F. '{ print $1 }')"
    H=$(expr $FULLS / 3600)
    M=$(expr $FULLS / 60)
    S=$(expr $FULLS % 60)
    printf %02d:%02d:%02d $H $(expr $M % 60) $S
}

echo "IF = $INPUT_FILENAME"
DURATION="$(calc_duration "$INPUT_FILENAME")"
echo "DURATION: $DURATION"
OFFSETS="$(calc_parts $DURATION $COUNT)"
W="$(echo "$SIZE" | awk -Fx '{ print $1 }')"
H="$(echo "$SIZE" | awk -Fx '{ print $2 }')"

I=0
for OFFSET in $OFFSETS ; do
    I=$(expr $I + 1)
    if [ "$ONEPOS" != "" ] && [ "$ONEPOS" != "$(expr $I - 1)" ] ; then
        continue
    fi
    OUTF="${OUT_FILENAME}.$(expr $I - 1 || true).jpeg"
    if [ "$ONEPOS" != "" ] ; then
        OUTF="$OUT_FILENAME"
    fi
    mkdir -p "$(dirname "$OUTF")"
    ffmpeg -i "$INPUT_FILENAME" -ss "$(to_ss $OFFSET)" -vframes 1 -vf scale=${W}:${H} -y "$OUTF"
done

