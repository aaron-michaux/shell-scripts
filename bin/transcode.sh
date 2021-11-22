#!/bin/bash

# ---------------------------------------------------------------------- Options

F=
OVERWRITE=0
PRINT_BITRATE=0
SERENITY=0
BITRATE=2000
FORMAT=
SS=
TT=
O=
VERBOSE=0
MAX_W=0

# ---------------------------------------------------------------- Help

show_help()
{
    cat <<EOF

   Usage: $(basename "$0") -i <filename> [OPTIONS...] <filename>

   Options:

      -i  <filename>    Input movie file
      -y                Allow overwrite of output file

      -p                Print the bitrate (in kb/s) and exit
      -f  <format>      Output format, like 1024:768
      --mw <integer>    Maximum width of output. (Aspect ratio preserved.)
      -b  <integer>     Set the bitrate, in kb/s. (An integer)
      -s  <timestamp>   Start at timestamp
      -t  <timestamp>   Encode duration
      -v                Verbose

      --serenity        Transcode on serenity

   Example:

      # Transcode 'movie.mp4' at 2200 kbit/s, skipping 30s, and duration is 10s
      ~ > $(basename "$0") -i movie.mp4 -b 2200 -s 00:00:30.0 -t 00:00:10.0 out.mp4

      # Transcode to '-1:720' (i.e., 720 height, preserving aspect ratio)
      ~ > $(basename "$0") -i movie.mp4 -f -1:720 out.mp4
EOF
}

for T in "$@" ; do
    ARG="$1"
    shift
    [ "$ARG" = "" ] && continue
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
    [ "$ARG" = "-i" ] && F="$1" && shift && continue
    [ "$ARG" = "-y" ] && OVERWRITE=1 && continue
    [ "$ARG" = "-p" ] && PRINT_BITRATE=1 && continue
    [ "$ARG" = "-f" ] && FORMAT="$1" && shift && continue
    [ "$ARG" = "--mw" ] && MAX_W="$1" && shift && continue
    [ "$ARG" = "-b" ] && BITRATE="$1" && shift && continue
    [ "$ARG" = "-s" ] && SS="$1" && shift && continue
    [ "$ARG" = "-t" ] && TT="$1" && shift && continue
    [ "$ARG" = "-v" ] && VERBOSE=1 && continue
    [ "$ARG" = "--serenity" ] && SERENITY=1 && continue
    O="$ARG"
done

! [ -f "$F" ] && \
    echo "Failed to find input file '$F'" 1>&2 && \
    exit 1
[ "$O" = "" ] && [ "$PRINT_BITRATE" != "1" ] && \
    echo "Must specify an output file!" 1>&2 && \
    exit 1
! [ "$BITRATE" -eq "$BITRATE" 2>/dev/null ] && \
    echo "Bitrate should be an integer: got '$BITRATE'" 1>&2 && \
    exit 1
! [ -f "$F" ] && \
    echo "Failed to find input file '$F', aborting." 1>&2 && \
    exit 1
[ -f "$O" ] && [ "$OVERWRITE" = "0" ] && \
    echo "Cowardly refusing to overwrite '$O', aborting." 1>&2 && \
    exit 1
! [ "$MAX_W" -eq "$MAX_W" 2>/dev/null ] && \
    echo "Max width (--mw) must be an integer, got '$MAX_W'" 1>&2 && \
    exit 1
# [ "$MAX_W" -lt "32" 2>/dev/null ] && \
#     echo "Max width (--mw) looks too small, got '$MAX_W'" 1>&2 && \
#     exit 1
! [ "$MAX_W" = "0" ] && ! [ "$FORMAT" = "" ] && \
    echo "Cannot specify format and max-width at the same time" 1>&2 && \
    exit 1

# ------------------------------------------------------------------------------

PPWD="$(cd "$(dirname "$0")" ; pwd)"
TMPD="$(mktemp -d "/tmp/$(basename $0).XXXXX")"

trap cleanup EXIT
cleanup()
{
    rm -rf "$TMPD"
}

absfilename()
{
    echo "$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
}

extension()
{
    local FILENAME="$1"
    local EXT="$(echo "$FILENAME" | awk -F . '{if (NF>1) { print $NF }}')"
    echo "$EXT"
}

calc_bitrate()
{
    F="$1"
    LINE="$(ffmpeg -nostdin -i "$F" 2>&1 | grep bitrate  | head -n 1)"
    RATE="$(echo "$LINE" | awk '{ print $6 }')"
    UNIT="$(echo "$LINE" | awk '{ print $7 }')"

    [ "$UNIT" != "kb/s" ] && \
        echo "unknown units: $LINE, UNIT='$UNIT'" 1>&2 && \
        exit 1
    echo "$RATE"
}

# ------------------------------------------------------------------------------

OUT_FILE="$(absfilename "$O")"
IN_FILE="$(absfilename "$F")"
SS_OPT=""
TT_OPT=""
FMT_OPT=""
QUIET="-loglevel quiet"
[ "$SS" != "" ] && SS_OPT="-ss $SS"
[ "$TT" != "" ] && TT_OPT="-t $TT"
[ "$FORMAT" != "" ] && FMT_OPT="-vf scale=$FORMAT"
[ "$VERBOSE" = "1" ] && QUIET=""
[ "$MAX_W" != "0" ] && FMT_OPT="-vf \"scale='min($MAX_W,iw)':-2\""

# Check the extension of $OUT_FILE
! [ "$(extension "$O")" = "mp4" ] && [ "$PRINT_BITRATE" != "1" ] && \
    echo "Output file extension must be 'mp4'. Got: '$O'" 1>&2 && \
    exit 1

# ----------------------------------------------------------------------- Action

IN_BITRATE="$(calc_bitrate "$IN_FILE" 2>/dev/null)"
SUCCESS="$?"
[ "$SUCCESS" != "0" ] && \
    echo "Failed to calculate bitrate: perhaps not a movie file?" 1>&2 && \
    exit 1

if [ "$PRINT_BITRATE" = "1" ] ; then
    echo "$IN_BITRATE"
    exit 0
fi

cat <<EOF

   Transcode Operation:

      File:        '$IN_FILE', $IN_BITRATE (kbits/s)
      Output:      '$OUT_FILE', $BITRATE (kbits/s)
      Format:      '$FMT_OPT'
      Start:       '$SS'
      Duration:    '$TT'
      Serenity:    '$SERENITY'

EOF

do_it()
{
    cd "$TMPD"

    echo "nice ionice -c3 ffmpeg -nostdin -hide_banner $QUIET -y $SS_OPT -i $(printf %q "$IN_FILE")  $TT_OPT $FMT_OPT -c:v libx264 -preset slow -b:v ${BITRATE}k -c:a libmp3lame -b:a 192k -f mp4 $(printf %q "$OUT_FILE")" | dash
    return $?

    if [ "1" = "0" ] ; then
        nice ionice -c3 ffmpeg -nostdin -hide_banner $QUIET -y $SS_OPT -i "$IN_FILE" $TT_OPT -c:v libx264 -preset slow -b:v ${BITRATE}k -pass 1 -an -f mp4 /dev/null \
        && nice ionice -c3 ffmpeg -nostdin -hide_banner $QUIET -y $SS_OPT -i "$IN_FILE"  $TT_OPT $FMT_OPT -c:v libx264 -preset slow -b:v ${BITRATE}k -pass 2 -c:a libmp3lame -b:a 192k -f mp4 "$OUT_FILE"
    fi

    nice ionice -c3 ffmpeg -nostdin -hide_banner $QUIET -y $SS_OPT -i "$IN_FILE"  $TT_OPT $FMT_OPT -c:v libx264 -preset slow -b:v ${BITRATE}k -c:a libmp3lame -b:a 192k -f mp4 "$OUT_FILE" 
    RET=$?
    
    return $RET
}

if [ "$SERENITY" = "0" ] ; then
    
    time do_it
    exit $?
    
else

    HOST=serenity    
    
    ID="~/TMP/$(basename "$TMPD")"
    
    cp "$IN_FILE" $TMPD/in-file
    cp "$0" $TMPD

    cat > $TMPD/script.sh <<EOF

cd $ID
$ID/transcode.sh -i $ID/in-file -y -f "$FORMAT" -b "$BITRATE" -s "$SS" -t "$TT" $ID/out-file.mp4 1>$ID/stdout.text 2>$ID/stderr.text
RESULT=\$?
echo \$RESULT > $ID/exit-code
rm -f $ID/in-file

EOF

    chmod 755 $TMPD/script.sh
    
    rsync -av "$TMPD/" "$HOST:$ID" 1>/dev/null

    autossh -t $HOST "$ID/script.sh"

    rsync -av "$HOST:$ID/" "$TMPD" 1>/dev/null

    autossh -t $HOST "rm -rf $ID"

    RESULT=$(cat $TMPD/exit-code)

    if [ "$RESULT" = "0" ] ; then
        cp $TMPD/out-file.mp4 "$OUT_FILE"
    fi
    
    exit $RESULT
    
fi



