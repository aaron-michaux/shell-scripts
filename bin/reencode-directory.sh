#!/bin/bash

set -e
set -o pipefail

PPWD="$(cd "$(dirname "$0")/.." ; pwd -P)"

INPUT_D=""
OUTPUT_D=""
WHITELIST_F=""
TMPD=$(mktemp -d "/tmp/$(basename "$0").XXXXX")
MAX_BITRATE=3000
MAX_COUNTER=0
DESIRED_CODEC="hevc"
CRF="27"

TOTALS_F="$TMPD/totals"
TRANSCODED_COUNTER_F="$TMPD/transcoded_counter"
MANIFEST_F="$TMPD/manifest.text"
MANIFEST_SIZE=0

COLOUR_ERROR='\e[0;91m'
COLOUR_WHITELIST='\e[0;97m'
COLOUR_DONE='\e[0;94m'
COLOUR_PROCESS='\e[0;92m'
COLOUR_ALL_GOOD="\e[0;96m"
COLOUR_NOT_MOVIE="\e[0;90m"
COLOUR_CLEAR='\e[0;0m'

trap cleanup EXIT
cleanup()
{
    rm -rf "$TMPD"
}

show_help()
{
    cat <<EOF

   Usage: $(basename "$0") [OPTIONS...]

      Re-encodes a directory tree of video files, saving the re-encoded (only) files
      at equivalent paths in a new directory tree.

   Required Arguments

      -i <path>           An input directory
      -o <path>           Output directory
      -w <filename>       A white-list file, where each line lists a video file to skip

   Options With Defaults      

      -c|--codec <codec>  The desired codec; default is $DESIRED_CODE
      --crf <int>         Constant quality rate to use with codec; default is $CRF
      --max-bitrate <int> Do not encode desired-codec videos with bitrate less than this; default i $MAX_BITRATE (kb/s)

EOF
}

# -- Parse Command-line

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] && [ "$ARG" = "--help" ] && show_help && exit 0
done

while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "-i" ] && INPUT_D="$1" && shift && continue
    [ "$ARG" = "-o" ] && OUTPUT_D="$1" && shift && continue
    [ "$ARG" = "-w" ] && WHITELIST_F="$1" && shift && continue
    [ "$ARG" = "-c" ] || [ "$ARG" = "--code" ] && DESIRED_CODEC="$1" && shift && continue
    [ "$ARG" = "-crf" ] || [ "$ARG" = "--crf" ] && CRF="$1" && shift && continue
    [ "$ARG" = "-max-bitrate" ] || [ "$ARG" = "--max-bitrate" ] && MAX_BITRATE="$1" && shift && continue
    echo "Unexpected argument: '$ARG'" 1>&2 && exit 1
done

[ ! -d "$INPUT_D" ]  && echo "Input directory not found: '$INPUT_D'"   1>&2 && exit 1 || true
[ ! -d "$OUTPUT_D" ] && echo "Output directory not found: '$OUTPUT_D'" 1>&2 && exit 1 || true
[ "$WHITELIST_F" != "" ] && [ ! -f "$WHITELIST_F" ] \
    && echo "Whitelist file not found: '$WHITELIST_F'" 1>&2 && exit 1 || true

LOG_F="$OUTPUT_D/log.text"

# -- Total

init_total()
{
    echo "0" > "$TOTALS_F"
}

get_total()
{
    cat "$TOTALS_F"
}

update_total()
{
    local DELTA="$1"
    local SUM="$(get_total)"
    echo "scale=3 ; $SUM + $DELTA" | bc > "$TOTALS_F"
}

# -- Transcoded Counter

init_transcoded_counter()
{
    echo "0" > "$TRANSCODED_COUNTER_F"
}

get_transcoded_counter()
{
    cat "$TRANSCODED_COUNTER_F"
}

update_transcoded_counter()
{
    local SUM="$(get_transcoded_counter)"
    echo "$SUM + 1" | bc > "$TRANSCODED_COUNTER_F"
}

# -- Movie info

is_movie_file()
{
    local FILENAME="$1"
    [ "$(du -b "$FILENAME")" -lt "10240" 2>/dev/null ] && return 1
    ffprobe "$FILENAME" 2>/dev/null 1>/dev/null && return 0
    return 1
}

is_on_white_list()
{
    local FILENAME="$1"
    if [ -f "$WHITELIST_F" ] ; then
        local PATTERN="$(echo "$FILENAME" | sed 's,\[,\\[,g' | sed 's,\],\\],g')"
        cat "$WHITELIST_F" | grep -q "$PATTERN" && return 0
    fi
    return 1
}

probe_info()
{
    local FILENAME="$1"
    ffprobe -v error -hide_banner -of default=noprint_wrappers=0 -print_format flat -select_streams v:0 -show_entries stream=bit_rate,codec_name,duration,width,height,pix_fmt -sexagesimal "$FILENAME" 2>/dev/null  | sed 's,^streams.stream.0.,,' | sed 's,",,g'
}

calc_codec()
{
    local F="$1"
    probe_info "$F" | grep -E "^codec_name" | awk -F= '{ print $2 }'
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

calc_pixfmt()
{
    local F="$1"
    probe_info "$F" | grep -E "^pix_fmt" | awk -F= '{ print $2 }'
}

print_info()
{
    local F="$1"
    printf "%s %s kb/s %dx%d %s" \
           "$(calc_codec "$F")" \
           "$(calc_bitrate "$F")" \
           "$(calc_width "$F")" \
           "$(calc_height "$F")" \
           "$(calc_pixfmt "$F")"    
}

# -- File info

extension()
{
    local FILENAME="$1"
    local EXT="$(echo "$FILENAME" | awk -F . '{if (NF>1) { print $NF }}')"
    echo "$EXT"
}

extensionless()
{
    local FILENAME="$1"
    local EXT="$(echo "$FILENAME" | awk -F . '{if (NF>1) { print $NF }}')"
    if (( ${#EXT} > 0 )) ; then
	echo "${FILENAME:0:$(expr ${#FILENAME} -  ${#EXT} - 1)}"
    else
	echo "$FILENAME"
    fi
}

file_size()
{
    local FILENAME="$1"
    du -b "$FILENAME" | awk '{ print $1 }'
}

delta_megabytes()
{
    local FILE_A="$1"
    local FILE_B="$2"
    echo "scale=3 ; ($(file_size "$FILE_A") - $(file_size "$FILE_B")) / (1024 * 1024)" | bc
}

output_base_filename()
{
    local FILENAME="$1"
    echo "$(dirname "$FILENAME")/$(extensionless "$(basename "$FILENAME")").mp4"
}

tmp_filename()
{
    local FILENAME="$1"
    echo "$TMPD/$(output_base_filename "$FILENAME")"
}

output_filename()
{
    local FILENAME="$1"
    echo "$OUTPUT_D/$(output_base_filename "$FILENAME")"
}

# -- Transcoding

print_transcode_cmd()
{
    local FILE="$1"
    local TMPF="$2"
    echo -n "transcode.sh -i $(printf %q "$FILE") --crf $CRF --${DESIRED_CODEC} --mw 1280 $(printf %q "$TMPF")"
}

transcode_one()
{
    FILE="$1"
    BASEF="$(output_base_filename "$FILE")"
    TMPF="$(tmp_filename "$FILE")"
    OUTF="$(output_filename "$FILE")"
    
    mkdir -p "$(dirname "$TMPF")"

    print_transcode_cmd "$FILE" "$TMPF" | sed 's,^,   ,' | tee -a "$LOG_F"    
    print_transcode_cmd "$FILE" "$TMPF" | dash | tee -a "$LOG_F"
            
    mkdir -p "$(dirname "$OUTF")"
    mv "$TMPF" "$OUTF"

    # Keep track of how many transcoding operations have finished
    update_transcoded_counter
}

# -- Set Extended Attributes on a File

set_xattr()
{
    local IN_FILE="$1"
    local OUT_FILE="$2"

    HASH="$(md5sum "$IN_FILE" | awk '{ print $1 }')"
    setfattr -n user.original_filename -v "$(basename "$IN_FILE")" "$OUT_FILE"
    setfattr -n user.original_file_md5 -v "$HASH" "$OUT_FILE"
    setfattr -n user.original_codec    -v "$(calc_codec "$IN_FILE")" "$OUT_FILE"
    setfattr -n user.original_bitrate  -v "$(calc_bitrate "$IN_FILE")" "$OUT_FILE"
    setfattr -n user.original_filesize -v "$(du -b "$IN_FILE" | awk '{ print $1 }')" "$OUT_FILE"
}

# -- Examining a file... may result in a transcode operation

examine_one()
{
    local FILENAME="$1"
    local JOB_COUNTER="$2"

    PROCESS_DESC="$(printf "[%0${#MANIFEST_SIZE}d/%d]" "$JOB_COUNTER" "$MANIFEST_SIZE")"

    if is_on_white_list "$FILENAME" ; then
        printf "${COLOUR_WHITELIST}$PROCESS_DESC Skipping '%s', it's on the white-list!${COLOUR_CLEAR}\n" "$FILENAME"
        return 0
    fi
    
    if ! is_movie_file "$FILENAME" ; then
        printf "${COLOUR_NOT_MOVIE}$PROCESS_DESC Skipping '%s', not a movie!${COLOUR_CLEAR}\n" "$FILENAME"
        return 0
    fi
    
    local BASEF="$(output_base_filename "$FILENAME")"
    local OUTF="$(output_filename "$FILENAME")"
    if [ -f "$OUTF" ] ; then
        local DELTA="$(delta_megabytes "$FILENAME" "$OUTF")"
        update_total "$DELTA"        
        printf "${COLOUR_DONE}$PROCESS_DESC Skipping %-80s (%s => %s)  delta: %s Megs${COLOUR_CLEAR}\n" \
               "$BASEF" \
               "$(print_info "$FILENAME")" \
               "$(print_info "$OUTF")" \
               "$DELTA" \
            | tee -a "$LOG_F"
        return 0
    fi

    local CODEC="$(calc_codec "$FILENAME")"
    local BR="$(calc_bitrate "$FILENAME")"
    if [ "$CODEC" = "" ] || ! [ "$BR" -eq "$BR" 2>/dev/null ] ; then
        echo "${COLOUR_ERROR}$PROCESS_DESC [ERROR]${COLOUR_CLEAR} probe_info '$FILENAME' returned: "
        probe_info "$FILENAME" | tr '\n' ' '
        return 0
    fi
    if [ "$CODEC" = "$DESIRED_CODEC" ] && (( $BR < $MAX_BITRATE )) ; then
        printf "${COLOUR_ALL_GOOD}$PROCESS_DESC Skipping %-80s (%s), bitrate less than $MAX_BITRATE${COLOUR_CLEAR}\n" \
               "$FILENAME" \
               "$(print_info "$FILENAME")" \
            | tee -a "$LOG_F"
        return 0
    fi

    echo -e "${COLOUR_PROCESS}$PROCESS_DESC Transcoding '$FILENAME'${COLOUR_CLEAR}" | tee -a "$LOG_F"
    echo "   $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_F"

    local NOW="$(date '+%s')"
    transcode_one "$FILENAME"
    set_xattr "$FILENAME" "$OUTF"

    local MINUTES="$(echo "scale=2 ; ($(date '+%s') - $NOW) / 60" | bc)"
    local DELTA="$(delta_megabytes "$FILENAME" "$OUTF")"
    update_total "$DELTA"

    echo "   Total Time:  $MINUTES minutes"
    echo "   Output Info: $(print_info "$OUTF")"
    echo "   Final Size:  $(du -sh "$OUTF" | awk '{ print $1 }')"
    echo "   Delta MiB:   $DELTA"

}

# -- Process an entire directory

print_manifest()
{
    D="$1"
    cd "$D"
    find . -type f | sed 's,^./,,' | sort
}

process_dir()
{
    D="$1"
    cd "$D"

    print_manifest > "$MANIFEST_F"
    MANIFEST_SIZE="$(cat "$MANIFEST_F" | wc -l)"

    # 1-index counter to be human readable
    COUNTER=1
    while read FILENAME ; do

        
        examine_one "$FILENAME" "$COUNTER"
        COUNTER=$(expr $COUNTER + 1)

        
        # Exit if we've reached the maximum number of files to do
        TRANSCODED_COUNTER=$(get_transcoded_counter)
        if [ "$MAX_COUNTER" -ne "0" ] && [ "$TRANSCODED_COUNTER" -ge "$MAX_COUNTER" ] ; then
            echo "Transcoded the max number of files: $TRANSCODED_COUNTER"
            break
        fi

    done  < <(cat "$MANIFEST_F")
}

# -- ACTION!

mkdir -p "$(dirname "$LOG_F")"    
printf '\n\n\n# --------------------------------------------- START (%s)\n' "$(date)" | tee "$LOG_F"
echo "Input Directory:  $INPUT_D"     | tee "$LOG_F"
echo "Output Directory: $OUTPUT_D"    | tee "$LOG_F"
echo "Whitelist file:   $WHITELIST_F" | tee "$LOG_F"
echo "Log file:         $LOG_F"       | tee "$LOG_F"
init_total
init_transcoded_counter
process_dir "$INPUT_D"

echo "Total Saved: $(echo "scale=3 ; $(get_total) / 1024" | bc) Gigs"
