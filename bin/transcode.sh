#!/bin/bash

set -e
set -o pipefail

# ---------------------------------------------------------------------- Options

F=
OVERWRITE=0
PRINT_BITRATE=0
PRINT_INFO="False"
RUN_ENCODE="True"
BITRATE=2000
AUDIO_SAMPLE_RATE=
USE_CRF="True"
BITRATE_SPECIFIED="False"
CRF_SPECIFIED="False"
FORMAT=
SS=00:00:00.000
TO=
TT=
O=
VERBOSE=0
MAX_W=0
AV1_LIB=libaom-av1
AV1_LIB=libsvtav1
ENCODING=libx265
TWO_PASS="False"
PRESET="slow"
MAX_QUEUE_SIZE=10240
CONTAINER="mp4"

# Set the default CRF
if [ "$ENCODING" = "libx264" ] ; then
    CRF=20
elif [ "$ENCODING" = "libx265" ] ; then
    CRF=27
elif [ "$ENCODING" = "libsvtav1" ] ; then
    CRF=30
elif [ "$ENCODING" = "libaom-av1" ] ; then
    CRF=30
else
    CRF=27
fi

# ------------------------------------------------------------------------- Help

show_help()
{
    cat <<EOF

   Usage: $(basename "$0") -i <filename> [OPTIONS...] <filename>

   Options:

      -i  <filename>    Input movie file.
      -y                Allow overwrite of output file.

      --print-bitrate   Print the bitrate (in kb/s) and exit.
      --info            Print info and exit.
      -f  <format>      Output format, like 1024:768.
      --mw <integer>    Maximum width of output. (Aspect ratio preserved.)
      -b  <integer>     Set the bitrate, in kb/s. (An integer.)
      --crf <integer>   Set the "contrant-rate-factor"; incompatible with bitrate.
      -s  <timestamp>   Start at timestamp.
      -to <timestamp>   End at timestamp.
      -t  <seconds>     Encode duration. (Incompatible with -to.)
      -v                Verbose.
      --preset <string> Default is 'slow'

      --h264            Use h264 encoding.
      --h265,--hevc     Use h265 encoding.
      --av1             Use av1  encoding.

      --1-pass          Use 1-pass encoding
      --2-pass          Use 2-pass encoding

   Examples:

      # Transcode 'movie.mp4' at 2200 kbit/s, skipping 30s, and duration is 10s
      ~ > $(basename "$0") -i movie.mp4 -b 2200 -s 00:00:30.0 -t 00:00:10.0 out.mp4

      # Transcode to '-1:720' (i.e., 720 height, preserving aspect ratio)
      ~ > $(basename "$0") -i movie.mp4 -f -1:720 out.mp4
EOF
}

while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "" ] && continue
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
    [ "$ARG" = "-i" ]  && F="$1" && shift && continue
    [ "$ARG" = "-y" ]  && OVERWRITE=1 && continue
    [ "$ARG" = "--print-bitrate" ]  && PRINT_BITRATE=1 && continue
    [ "$ARG" = "--info" ] || [ "$ARG" = "-info" ] || [ "$ARG" = "-p" ] && PRINT_INFO="True" && continue
    [ "$ARG" = "-f" ]  && FORMAT="$1" && shift && continue
    [ "$ARG" = "--mw" ] || [ "$ARG" = "-mw" ] && MAX_W="$1" && shift && continue
    [ "$ARG" = "-b" ]  && BITRATE="$1" && USE_CRF="False" && BITRATE_SPECIFIED="True" && shift && continue
    [ "$ARG" = "--crf" ] || [ "$ARG" = "-crf" ] && CRF="$1"  && USE_CRF="True"  && CRF_SPECIFIED="True" && shift && continue
    [ "$ARG" = "--preset" ] || [ "$ARG" = "-preset" ] && PRESET="$1" && shift && continue
    [ "$ARG" = "-s" ]  && SS="$1" && shift && continue
    [ "$ARG" = "-t" ]  && TT="$1" && shift && continue
    [ "$ARG" = "-to" ] && TO="$1" && shift && continue
    [ "$ARG" = "-v" ]  && VERBOSE=1 && continue
    [ "$ARG" = "--h264" ]   || [ "$ARG" = "-h264" ]   && ENCODING="libx264" && continue
    [ "$ARG" = "--h265" ]   || [ "$ARG" = "-h265" ]   && ENCODING="libx265" && continue
    [ "$ARG" = "--hevc" ]   || [ "$ARG" = "-hevc" ]   && ENCODING="libx265" && continue
    [ "$ARG" = "--av1" ]    || [ "$ARG" = "-av1" ]    && ENCODING="$AV1_LIB" && continue
    [ "$ARG" = "--1-pass" ] || [ "$ARG" = "-1-pass" ] && TWO_PASS="False" && continue
    [ "$ARG" = "--2-pass" ] || [ "$ARG" = "-2-pass" ] && TWO_PASS="True"  && continue

    if [ "$O" = "" ] ; then
        O="$ARG"
    else
        echo "unexpected argument: '$ARG'" 1>&2 && exit 1
    fi
done

if [ "$PRINT_INFO" = "True" ] || [ "$PRINT_BITRATE" = "1" ] ; then
    RUN_ENCODE="False"
fi

! [ -f "$F" ] && \
    echo "Failed to find input file '$F'" 1>&2 && \
    exit 1
[ "$O" = "" ] && [ "$RUN_ENCODE" = "True" ] && \
    echo "Must specify an output file!" 1>&2 && \
    exit 1
! [ "$BITRATE" -eq "$BITRATE" 2>/dev/null ] && \
    echo "Bitrate should be an integer: got '$BITRATE'" 1>&2 && \
    exit 1
! [ "$CRF" -eq "$CRF" 2>/dev/null ] && \
    echo "CRF should be an integer: got '$CRF'" 1>&2 && \
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
! [ "$MAX_W" = "0" ] && ! [ "$FORMAT" = "" ] && \
    echo "Cannot specify format and max-width at the same time" 1>&2 && \
    exit 1
[ "$TT" != "" ] && [ "$TO" != "" ] && \
    echo "Cannot specify both -t and --to" 1>&2 && \
    exit 1
[ "$USE_CRF" = "True" ] && [ "$TWO_PASS" = "True" ] && [ "$BITRATE_SPECIFIED" = "False" ] && \
    echo "--2-pass only makes sense when specifying a bitrate: use -b <integer>" 1>&2 && \
    exit 1
[ "$BITRATE_SPECIFIED" = "True" ] && [ "$CRF_SPECIFIED" = "True" ] && \
    echo "Specify --crf <integer>, or -b <integer> but not both" 1>&2 && \
    exit 1
[ "$ENCODING" = "$AV1_LIB" ] && [ "$TWO_PASS" = "True" ] && \
    echo "Two-pass with $ENCODING not yet set up, sorry" 1>&2 && \
    exit 1
[ "$ENCODING" = "$AV1_LIB" ] && ! which SvtAv1EncApp 1>/dev/null && \
    echo "Could not find av1 binary on path: SvtAv1EncApp" 1>&2 && \
    exit 1
[ ! -d "$(dirname "$OUT_FILE")" ] && \
    echo "Output directory does not exist: $(cd "$(dirname "$OUT_FILE")" ; pwd)" 1>&2 && \
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
    local FILENAME="$1"
    if [ "${FILENAME:0:1}" = "/" ] ; then
        echo "$FILENAME"
        return 0
    fi
    echo "$(cd "$(dirname "$FILENAME")"; pwd -P)/$(basename "$FILENAME")"
}

extension()
{
    local FILENAME="$1"
    local EXT="$(echo "$FILENAME" | awk -F . '{if (NF>1) { print $NF }}')"
    echo "$EXT"
}

probe_info()
{
    local FILENAME="$1"
    local DATAF="$TMPD/$FILENAME.ffprobe"
    if [ ! -f "$DATAF" ] ; then
        mkdir -p "$(dirname "$DATAF")"
        ffprobe -v error -hide_banner -of default=noprint_wrappers=0 -print_format flat -select_streams v:0 -show_entries stream=bit_rate,codec_name,duration,width,height,pix_fmt -sexagesimal "$FILENAME" 2>/dev/null  | sed 's,^streams.stream.0.,,' | sed 's,",,g' > "$DATAF"
    fi
    cat "$DATAF"   
}

get_pixfmt()
{
    local FILENAME="$1"
    probe_info "$FILENAME" | grep -E "^pix_fmt=" | awk -F= '{ print $2 }'
}

calc_audio_sample_rate()
{
    local FILENAME="$1"
    local DATAF="$TMPD/$FILENAME.audio.ffprobe"
    if [ ! -f "$DATAF" ] ; then
        mkdir -p "$(dirname "$DATAF")"
        ffprobe -v error -hide_banner -of default=noprint_wrappers=0 -print_format flat -select_streams a:0 -show_entries stream=sample_rate "$FILENAME" 2>/dev/null  | sed 's,^streams.stream.0.sample_rate=,,' | sed 's,",,g' > "$DATAF"
    fi
    cat "$DATAF"   
}

calc_codec()
{
    local F="$1"
    probe_info "$F" | grep -E "^codec_name" | awk -F= '{ print $2 }'
}

print_info()
{
    local FILENAME="$1"
    probe_info "$FILENAME"
    echo "sample_rate=$(calc_audio_sample_rate "$IN_FILE")"    
}

calc_bitrate()
{
    local F="$1"
    local BR="$(probe_info "$F" | grep -E "^bit_rate" | awk -F= '{ print $2 }')"

    if [ "$BR" -eq "$BR" 2>/dev/null ] ; then
        echo "scale=0 ; $BR / 1000" | bc
        return 0
    fi
    local LINE="$(ffmpeg -nostdin -i "$F" 2>&1 | grep bitrate  | head -n 1)"
    local RATE="$(echo "$LINE" | awk '{ print $6 }')"
    local UNIT="$(echo "$LINE" | awk '{ print $7 }')"
    if [ "$UNIT" != "kb/s" ] ; then
        echo "Could not calculate birate, unknown unit: '$UNIT' in line '$LINE'" 1>&2
        exit 1
    fi
    echo "$RATE"
}

calc_movie_length()
{
    F="$1"
    local F="$1"
    probe_info "$F" | grep -E "^duration" | awk -F= '{ print $2 }'
}

# Convert a timestamp to seconds
to_seconds()
{
    local TS="$1"
    if [ "${TS:2:1}" != ":" ] || [ "${TS:5:1}" != ":" ] ; then
        echo "Invalid timestamp '$TS', should be of format HH:MM:SS(.[0-9]*)?"
        exit 1
    fi
    H="${TS:0:2}"
    M="${TS:3:2}"
    S="${TS:6}"
    echo "$H * 3600 + $M * 60 + $S" | bc    
}

# Second difference between two timestamps
ts_diff()
{
    local A="$(to_seconds "$1")"
    local B="$(to_seconds "$2")"
    echo "$B - $A" | bc
}

# ------------------------------------------------------------------------------

OUT_FILE="$(absfilename "$O")"
IN_FILE="$(absfilename "$F")"
SS_OPT=""
TT_OPT=""
FMT_OPT=""
QUIET="-v quiet"
[ "$SS" != "" ] && [ "$SS" != "00:00:00.000" ] && SS_OPT="-ss $SS"
[ "$TT" != "" ] && TT_OPT="-t $TT"
[ "$TO" != "" ] && TT_OPT="-t $(ts_diff $SS $TO)"
[ "$FORMAT" != "" ] && FMT_OPT="-vf scale=$FORMAT"
[ "$VERBOSE" = "1" ] && QUIET=""
[ "$MAX_W" != "0" ] && FMT_OPT="-vf \"scale='min($MAX_W,iw)':-2\""
[ "$ENCODING" = "libx264" ] && PASS1="-pass 1" && PASS2="-pass 2"
[ "$ENCODING" = "libx265" ] && PASS1="-x265-params pass=1" && PASS2="-x265-params pass=2"

# Check the extension of $OUT_FILE
[ "$(extension "$O")" != "mp4" ] && [ "$(extension "$O")" != "mkv" ] && [ "$RUN_ENCODE" = "True" ] && \
    echo "Output file extension must be 'mp4'. Got: '$O'" 1>&2 && \
    exit 1

if [ "$(extension "$O")" = "mkv" ] ; then
    CONTAINER="matroska"
elif [ "$(extension "$O")" = "mp4" ] ; then
    CONTAINER="mp4"
fi

# ----------------------------------------------------------------------- Action

if [ "$PRINT_INFO" = "True" ] ; then
    print_info "$IN_FILE"
    exit 0
fi

IN_BITRATE="$(calc_bitrate "$IN_FILE" 2>/dev/null)"
SUCCESS="$?"
[ "$SUCCESS" != "0" ] && \
    echo "Failed to calculate bitrate: perhaps not a movie file?" 1>&2 && \
    exit 1

if [ "$PRINT_BITRATE" = "1" ] ; then
    echo "$IN_BITRATE"
    exit 0
fi

[ "$USE_CRF" = "True" ] && QUALITY_MESSAGE="CRF=$CRF" || QUALITY_MESSAGE="$BITRATE (kbits/s)"
[ "$USE_CRF" = "True" ] && QUALITY_ARG="-crf $CRF"    || QUALITY_ARG="-b:v ${BITRATE}k"
[ "$QUIET" != "" ] && [ "$ENCODING" = "libx265" ] && QUIET_PARAM="-x265-params log-level=none" || QUIET_PARAM=""

IN_SAMPLE_RATE="$(calc_audio_sample_rate "$IN_FILE" 2>/dev/null)"
if [ "$IN_SAMPLE_RATE" -eq "$IN_SAMPLE_RATE" 2>/dev/null ] ; then
    true
else
    IN_SAMPLE_RATE="0"
fi
if [ "$IN_SAMPLE_RATE" -eq "24000" ] ||
       [ "$IN_SAMPLE_RATE" -eq "44100" ] ||
       [ "$IN_SAMPLE_RATE" -eq "48000" ] ; then
    SAMPLE_RATE_ARG=""
else
    SAMPLE_RATE_ARG="-ar 44100"
    QUALITY_MESSAGE+=", resampled to 44100 Hz"
fi

preset_arg()
{
    if [ "$ENCODING" = "$AV1_LIB" ] ; then
        [ "$PRESET" = "ultrafast" ] && echo 13 && return 0 || true
        [ "$PRESET" = "superfast" ] && echo 12 && return 0 || true
        [ "$PRESET" = "veryfast" ] && echo 11 && return 0 || true
        [ "$PRESET" = "faster" ] && echo 10 && return 0 || true
        [ "$PRESET" = "fast" ] && echo 9 && return 0 || true
        [ "$PRESET" = "medium" ] && echo 8 && return 0 || true
        [ "$PRESET" = "slow" ] && echo 7 && return 0 || true
        [ "$PRESET" = "slower" ] && echo 5 && return 0 || true
        [ "$PRESET" = "veryslow" ] && echo 3 && return 0 || true
        [ "$PRESET" = "placebo" ] && echo 0 && return 0 || true
    else
        echo "$PRESET"
        return 0
    fi
    echo "Invalid preset=$PRESET" 1>&2
    exit 1
}

print_cmd()
{
    PIXFMT="$(get_pixfmt "$IN_FILE")"
    PIXFMT=""
    ANALYZE="-probesize 100M -analyzeduration 500M"
    [ "$ENCODING" = "$AV1_LIB" ] && PIXFMT="-pix_fmt yuv420p10le" || PIXFMT="-pix_fmt yuv420p"

    # Notes:
    #    "-strict -1" is for dealing with unusal sample rates in mp3s
    #    "-ar 48000"  forces the audio sample rate to 48k
    # -c:s mov_text
    # -scodec copy
    
    if [ "$TWO_PASS" = "False" ] ; then
        echo "nice ffmpeg -nostdin -hide_banner $QUIET $ANALYZE -y $SS_OPT -i $(printf %q "$IN_FILE")  $TT_OPT $FMT_OPT $PIXFMT -c:v $ENCODING -preset $(preset_arg) $QUIET_PARAM $QUALITY_ARG -c:a libmp3lame $SAMPLE_RATE_ARG -b:a 192k -scodec copy -f $CONTAINER -max_muxing_queue_size $MAX_QUEUE_SIZE $(printf %q "$OUT_FILE")"
        
    else
        echo "nice ffmpeg -nostdin -hide_banner $QUIET $ANALYZE -y $SS_OPT -i $(printf %q "$IN_FILE")  $TT_OPT $FMT_OPT $PIXFMT -c:v $ENCODING -preset $(preset_arg) $QUIET_PARAM $QUALITY_ARG $PASS1 -an -f null /dev/null && nice ffmpeg -nostdin -hide_banner $QUIET -y $SS_OPT -i $(printf %q "$IN_FILE")  $TT_OPT $FMT_OPT $PIXFMT -c:v $ENCODING -preset $(preset_arg) $QUIET_PARAM $QUALITY_ARG $PASS2 -c:a libmp3lame $SAMPLE_RATE_ARG -b:a 192k -f $CONTAINER -max_muxing_queue_size $MAX_QUEUE_SIZE $(printf %q "$OUT_FILE")"
        
    fi
}

cat <<EOF

   Transcode Operation:

      File:        '$IN_FILE', $(calc_codec "$IN_FILE"), $IN_BITRATE (kbits/s), $IN_SAMPLE_RATE Hz
      Output:      '$OUT_FILE', $QUALITY_MESSAGE
      Movie Length: $(calc_movie_length "$IN_FILE")
      Size:         $(du -sh "$IN_FILE" | awk '{ print $1 }')
      Format:       $FMT_OPT
      Start:        $SS
      End:          $TO
      Duration:     $TT
      Preset:       $PRESET
      Command:      $(print_cmd)

EOF

do_it()
{
    cd "$TMPD"
    print_cmd | dash && return 0

    if [ "$VERBOSE" = "0" ] ; then
        # Run the command without quiet, so
        # end-user can see log messages
        QUIET=""
        print_cmd | dash
    fi
    return 1
}

do_it

exit $?

# SvtAv1
#ffmpeg -i Infile.mp4 -map 0:v:0 -pix_fmt yuv420p10le -f yuv4mpegpipe -strict -1  - | SvtAv1EncApp -i stdin --preset 6 --keyint 240 --input-depth 10 --crf 30 --rc 0 --passes 1 --film-grain 0 -b Outfile.ivf

