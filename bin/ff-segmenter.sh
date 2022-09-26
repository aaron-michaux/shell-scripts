#!/bin/bash

set -e

# ---------------------------------------------------------------------- Options

FILE=
OUTF=
OVERWRITE="False"
CUTS="False"
PRINT_CUTS="False"

TMPD="$(mktemp -d "/tmp/$(basename "$0").XXXXXX")"
trap cleanup EXIT
cleanup()
{
    rm -rf "$TMPD"
}
SEGFILE="$TMPD/segments.text"
CUTLIST="$TMPD/cuts.text"
MANIFESTF="$TMPD/manifest.text"
touch "$SEGFILE"
touch "$CUTLIST"
touch "$MANIFESTF"
MAX_TS="99:59:59.999"

# -------------------------------------------------------------------- Functions

fail_ts()
{
    local RAW="$1"
    local MSG="$2"
    echo "Failed to decode '$RAW': $MSG" 1>&2
    exit 1
}

check_hms()
{
    local RAW="$1"
    local VAL="$2"
    local MIN="$3"
    local MAX="$4"    
    ! [ "$VAL" -eq "$VAL" 2>/dev/null ] \
        && fail_ts "$RAW" "bad value '$VAL'" || true
    [ "$VAL" -lt "$MIN" ] && fail_ts "$RAW" "bad value '$VAL'" || true
    [ "$VAL" -gt "$MAX" ] && fail_ts "$RAW" "bad value '$VAL'" || true
    return 0
 }

decode_timestamp()
{
    local RAW="$1"
    X="$(echo "$RAW" | awk -F: '{ print $1 }')"
    Y="$(echo "$RAW" | awk -F: '{ print $2 }')"
    Z="$(echo "$RAW" | awk -F: '{ print $3 }')"
    W="$(echo "$RAW" | awk -F: '{ print $4 }')"
    [ "$W" != "" ] && fail_ts "$RAW" "to many ':' characters" || true
    [ "$X" = "" ] && [ "$Y" = "" ] && [ "$Z" = "" ] \
        && fail_ts "$RAW" "is empty" || true
    H="00"
    M="00"
    S="00.000"
    if [ "$Y" = "" ] && [ "$Z" = "" ] ; then
        S="$X"
    elif [ "$Z" = "" ] ; then
        M="$X"
        S="$Y"
    else
        H="$X"
        M="$Y"
        S="$Z"
    fi
    SECS="$(echo "$S" | awk -F. '{ print $1 }')"
    MILLIS="$(echo "$S" | awk -F. '{ print $2 }')"
    [ "$MILLIS" = "" ] && MILLIS="000" || true
    check_hms "$RAW" "$H" 0 99
    check_hms "$RAW" "$M" 0 59
    check_hms "$RAW" "$SECS" 0 59
    check_hms "$RAW" "$MILLIS" 0 999
    echo "$H:$M:$SECS.$MILLIS"
}

# Convert a timestamp to seconds
to_seconds()
{
    local TS="$1"
    H="${TS:0:2}"
    M="${TS:3:2}"
    S="${TS:6}"
    echo "$H * 3600 + $M * 60 + $S" | bc    
}

is_less_equal()
{
    local VAL="$(echo "$1 <= $2" | bc)"
    [ "$VAL" = "1" ] && return 0
    return 1
}

to_ts()
{
    local RAW="$1"
    H="$(echo "$RAW / 3600" | bc)"
    M="$(echo "($RAW / 60) % 60" | bc)"
    S="$(echo "$RAW % 60" | bc)"
    SECS="$(echo "$S" | awk -F. '{ print $1 }')"
    MILLIS="$(echo "$S" | awk -F. '{ print $2 }')"
    [ "$MILLIS" = "" ] && MILLIS="000" || true
    [ "${#MILLIS}" = "1" ] && MILLIS="${MILLIS}00" || true
    [ "${#MILLIS}" = "2" ] && MILLIS="${MILLIS}0" || true
    printf "%02d:%02d:%02d.%s" "$H" "$M" "$SECS" "$MILLIS"
}

# ------------------------------------------------------------------------- Help

show_help()
{
    cat <<EOF

   Usage: $(basename "$0") -i <filename> -o <filename> [OPTIONS...]

      -i <filename>     Input movie filename.
      -o <filename>     Output movie filename.
      
      -y                Allow overwrite of output file.

      -x                Segments are "cuts", as in, they are removed.
                        Otherwise segments are retained.

      -p                Print segment list and exit

      -s <start-end>    A segment. May be specified multiple times.

   Examples:

      # Remove segment from 3:11.200 until 4:00.000 (it's a commercial)
      > $(basename "$0") -i movie.mp4 -x -s 00:03:11.200-00:04:00.000 -o out.mp4

      # 

EOF
}

# ------------------------------------------------------------------------ Parse

while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
    [ "$ARG" = "-i" ] && FILE="$1" && shift && continue
    [ "$ARG" = "-o" ] && OUTF="$1" && shift && continue
    [ "$ARG" = "-y" ] && OVERWRITE="True" && continue
    [ "$ARG" = "-x" ] && CUTS="True" && continue
    [ "$ARG" = "-p" ] && PRINT_CUTS="True" && continue
    [ "$ARG" = "-s" ] && echo "$1" >> "$SEGFILE" && shift && continue
    echo "Unexpected argument: '$ARG', aborting" 1>&2
    exit 1
done

# ----------------------------------------------------------------------- Sanity

if [ "$FILE" = "" ] ; then
    echo "Must specify an input file!" 1>&2
    exit 1
fi

if [ ! -f "$FILE" ] ; then
    echo "Input file no found: '$FILE'" 1>&2
    exit 1
fi

if [ -f "$OUTF" ] && [ "$OVERWRITE" = "False" ] ; then
    echo "Cowardly refusing to overwite output file '$OUTF'" 1>&2
    exit 1
fi

N_SEGS="$(cat "$SEGFILE" | wc -l)"
if [ "$N_SEGS" = "0" ] ; then
    echo "Must specify at least 1 segment!" 1>&2 && exit 1
fi

# 1. Every timestamp must be in increasing order
# 2. A missing 'start' timestamp is 00:00:00.000
# 3. A missing 'end' timestamp is 99:99:99.999
LAST_SECONDS="0"
cat "$SEGFILE" | while read SEG ; do
    A="$(echo "$SEG" | awk -F- '{ print $1 }')"
    B="$(echo "$SEG" | awk -F- '{ print $2 }')"
    [ "$A" = "" ] && A="00:00:00.000" || true
    [ "$B" = "" ] && B="$MAX_TS" || true
    A="$(decode_timestamp "$A")"
    B="$(decode_timestamp "$B")"
    X="$(to_seconds "$A")"
    Y="$(to_seconds "$B")"

    ! is_less_equal "$LAST_SECONDS" "$X" \
        && echo "timestamps are not ascending" 1>&2 && exit 1
    ! is_less_equal "$X" "$Y" \
        && echo "timestamps are not ascending" 1>&2 && exit 1
    LAST_SECONDS="$Y"
    echo "$X" >> "$CUTLIST"    
    echo "$Y" >> "$CUTLIST"    
done

# If -x, then invert cuts by adding "00:00:00.000" at the start
if [ "$CUTS" = "True" ] ; then
    cp "$CUTLIST" "$TMPD/tmp-cutlist.text"
    echo "0" > "$CUTLIST"
    cat "$TMPD/tmp-cutlist.text" >> "$CUTLIST"
fi

# Consolidate the cuts into pairs... adding/removing the end
cp "$CUTLIST" "$TMPD/tmp-cutlist.text"
rm -f "$CUTLIST"
touch "$CUTLIST"
LAST_VALUE=""
cat "$TMPD/tmp-cutlist.text" | while read VALUE ; do
    if [ "$LAST_VALUE" != "" ] ; then
        echo "$LAST_VALUE $VALUE" >> "$CUTLIST"
        LAST_VALUE=""
    else
        LAST_VALUE="$VALUE"
    fi
done


# Add the last value if required
if [ "$(echo "$(cat "$TMPD/tmp-cutlist.text" | wc -l) % 2" | bc)" = "1" ] ; then
    LAST_VALUE="$(tail -n 1 "$TMPD/tmp-cutlist.text")"
    echo "$LAST_VALUE $(to_seconds $MAX_TS)" >> "$CUTLIST"    
fi

# Okay, remove zero-length elements
cp "$CUTLIST" "$TMPD/tmp-cutlist.text"
rm -f "$CUTLIST"
touch "$CUTLIST"
cat "$TMPD/tmp-cutlist.text" | while read A B ; do
    if [ "$A" != "$B" ] ; then
        echo "$A $B" >> "$CUTLIST"
    fi
done

# Convert cuts back to timestamps
cp "$CUTLIST" "$TMPD/tmp-cutlist.text"
rm -f "$CUTLIST"
touch "$CUTLIST"
cat "$TMPD/tmp-cutlist.text" | while read A B ; do
    echo "$(to_ts "$A") $(to_ts "$B")" >> "$CUTLIST"
done


# If the cutlist is empty, then error out
N_CUTS="$(cat "$CUTLIST" | wc -l)"
if [ "$N_CUTS" = "0" ] ; then
    echo "cut list is empty!" 1>&2
    exit 1
fi

# ----------------------------------------------------------------------- Action

if [ "$PRINT_CUTS" = "True" ] ; then
    cat <<EOF
$(basename $0) Action!

   FILE: "$FILE"
   OUTF: "$OUTF"
   -y     $OVERWRITE
   -x     $CUTS
   -p     $PRINT_CUTS

EOF

    cat "$CUTLIST" | sed 's,^,   ,'
    exit 0
fi

BITRATE="$(transcode.sh -i "$FILE" -p)"
I=0
cat "$CUTLIST" | while read A B ; do
    TMP_OUTF="$TMPD/out_$(printf %02d $I).mkv"
    echo "file '$TMP_OUTF'" >> "$MANIFESTF"

    END_OPT=""
    if [ "$B" != "$MAX_TS" ] ; then
        END_OPT="-to $B"
    fi
    transcode.sh -i "$FILE" -y -b "$BITRATE" -s "$A" $END_OPT -f "-1:720" "$TMP_OUTF"
    I="$(expr $I + 1)"
done
echo "nice ionice -c3 ffmpeg -y -nostdin -hide_banner -f concat -safe 0 -i $MANIFESTF -c copy $(printf %q "$OUTF")" | tee "$TMPD/cmd"
cat "$TMPD/cmd" | dash

