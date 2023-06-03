#!/bin/bash

set -e
set -o pipefail

PPWD="$(cd "$(dirname "$0")/.." ; pwd -P)"

INPUT_D=""
OUTPUT_D=""
WHITELIST_F=""
TMPD=$(mktemp -d "/tmp/$(basename "$0").XXXXXX")
MAX_BITRATE=3000
MAX_COUNTER=0
DESIRED_CODEC="hevc"
CRF="26"
MAX_W="1024"
KEEP_GOING="False"

CHECK_WHITELIST="False"
RECONCILE="False"

TOTALS_F="$TMPD/totals"
TRANSCODED_COUNTER_F="$TMPD/transcoded_counter"
MANIFEST_F="$TMPD/manifest.text"
MANIFEST_SIZE=0

COLOUR_ERROR='\e[0;91m'
COLOUR_WHITELIST='\e[0;97m'
COLOUR_WARNING='\e[0;93m'
COLOUR_DONE='\e[0;94m'
COLOUR_PROCESS='\e[0;92m'
COLOUR_ALL_GOOD="\e[0;96m"
COLOUR_NOT_MOVIE="\e[0;90m"
COLOUR_CLEAR='\e[0;0m'

PERC_THRESHOLD="20.0"

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
      -k                  Keep going if there's an error

   Utility Options

      --check-whitelist   Check the passed whitelist:
                           1. Do any files in the whitelist not exist in source?
                           2. Have any files in the whitelist been transcoded to dest?

      --reconcile         Movies files back from the encode directory to the source directory,
                          removing source files. (cp/rsync cannot be used because of file name changes.)

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
    [ "$ARG" = "-k" ] && KEEP_GOING="True" && continue
    [ "$ARG" = "--check-whitelist" ] && CHECK_WHITELIST="True" && continue
    [ "$ARG" = "--reconcile" ] && RECONCILE="True" && continue
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
    local INFO=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_name -print_format csv=p=0 "$FILENAME" 2>/dev/null || echo "")
    if [ "$INFO" = "mjpeg" ] && [ "$(du -b "$FILENAME" | awk '{ print $1 }')" -lt "4194304" ] ; then
        return 1
    fi
    if [ "$INFO" != "ansi" ] && [ "$INFO" != "" ] ; then
        return 0
    fi
    return 1
}

is_on_white_list()
{
    local FILENAME="$1"
    if [ -f "$WHITELIST_F" ] ; then
        while read MATCH ; do
            if [ "$FILENAME" = "$MATCH" ] ; then
                return 0
            fi
        done < <(cat "$WHITELIST_F" ; echo)
    fi
    return 1
}

probe_info()
{
    local FILENAME="$1"
    local DATAF="$TMPD/ffprobe_${FILENAME}"
    
    if [ ! -f "$DATAF" ] ; then
        mkdir -p "$(dirname "$DATAF")"
        ffprobe -v error -hide_banner -of default=noprint_wrappers=0 -print_format flat -select_streams v:0 -show_entries stream=bit_rate,codec_name,duration,width,height,pix_fmt -sexagesimal "$FILENAME" 2>/dev/null  | sed 's,^streams.stream.0.,,' | sed 's,",,g' 2>&1 > "$DATAF"
    fi
    
    cat "$DATAF"
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
        echo "Could not calculate bitrate, unknown unit: '$UNIT' in line '$LINE'" 1>&2
        exit 1
    fi
    echo "$RATE"
}

calc_width()
{
    local F="$1"
    local WIDTH="$(probe_info "$F" | grep -E "^width" | awk -F= '{ print $2 }')"

    if [ "$WIDTH" -eq "$WIDTH" 2>/dev/null ] ; then
        echo "$WIDTH"
        return 0
    fi
    local W2="$(ffmpeg -nostdin -i Foyles\ War\ -\ S01E01\ -\ The\ German\ Woman.avi 2>&1 | grep Video: | awk -F, '{ print $3 }' | awk -Fx '{ print $1 }' | sed 's,^ *,,')"
    if [ "$W2" -eq "$W2" 2>/dev/null ] ; then
        echo "$W2"
        return 0
    fi
    
    echo "Could not calculate width" 1>&2
    exit 1
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

# -- swap

swap_files()
{
    local TMPFILE="$TMPD/tmp.$$"
    mv "$1" "$TMPFILE"
    mv "$2" "$1"
    mv "$TMPFILE" "$2"
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

is_reencoded()
{
    local FNAME="$1"
    getfattr -n user.original_filename "$FNAME" 1>/dev/null 2>/dev/null && return 0 || return 1
}

reencode_was_attempted()
{
    local FNAME="$1"
    getfattr -n user.encode_attempt_gain "$FNAME" 1>/dev/null 2>/dev/null && return 0 || return 1
}

perc_gain()
{
    local FNAME="$1"
    
    # This only makes sense for reencoded files
    is_reencoded "$FNAME" || return 1

    local SZ_0="$(getfattr -d "$FNAME" 2>/dev/null | grep "user.original_filesize" | awk -F= '{ print $2 }' | sed 's,",,g')"
    local SZ_1="$(du -b "$FNAME" | awk '{ print $1 }')"
    local DIFF="$(echo "scale=9 ; ($SZ_0 - $SZ_1) / (1024 * 1024 * 1024)" | bc)"
    local PERC="$(echo "scale=2 ; ($SZ_0 - $SZ_1) / (0.01 * $SZ_0)" | bc)"

    echo "$PERC"
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
    echo -n "transcode.sh -i $(printf %q "$FILE") --crf $CRF --${DESIRED_CODEC} --mw $MAX_W $(printf %q "$TMPF")"
}

transcode_one()
{
    FILE="$1"
    BASEF="$(output_base_filename "$FILE")"
    TMPF="$(tmp_filename "$FILE")"
    OUTF="$(output_filename "$FILE")"
    
    mkdir -p "$(dirname "$TMPF")"

    print_transcode_cmd "$FILE" "$TMPF" | sed 's,^,   ,' | tee -a "$LOG_F"    
    print_transcode_cmd "$FILE" "$TMPF" | dash | tee -a "$LOG_F" && SUCCESS="True" || SUCCESS="False"
    if [ "$SUCCESS" = "False" ] ; then
        return 1
    fi
            
    mkdir -p "$(dirname "$OUTF")"
    mv "$TMPF" "$OUTF"

    # Keep track of how many transcoding operations have finished
    update_transcoded_counter
}

# -- Set Extended Attributes on a File

set_encoded_xattr()
{
    local IN_FILE="$1"
    local OUT_FILE="$2"

    HASH="$(md5sum "$IN_FILE" | awk '{ print $1 }')"
    setfattr -n user.encode_date       -v "$(date '+%Y-%m-%d %H:%M:%S')" "$OUT_FILE"
    setfattr -n user.original_filename -v "$(basename "$IN_FILE")"       "$OUT_FILE"
    setfattr -n user.original_file_md5 -v "$HASH"                        "$OUT_FILE"
    setfattr -n user.original_codec    -v "$(calc_codec "$IN_FILE")"     "$OUT_FILE"
    setfattr -n user.original_bitrate  -v "$(calc_bitrate "$IN_FILE")"   "$OUT_FILE"
    setfattr -n user.original_filesize -v "$(du -b "$IN_FILE" | awk '{ print $1 }')" "$OUT_FILE"
}

set_no_good_encode_xattr()
{
    local FNAME="$1"
    local GAIN="$2"
    setfattr -n user.encode_attempt_date -v "$(date '+%Y-%m-%d %H:%M:%S')"  "$FNAME"
    setfattr -n user.encode_attempt_gain -v "$GAIN"                         "$FNAME"
}

# -- Examining a file... may result in a transcode operation

examine_one()
{
    local FILENAME="$1"
    local JOB_COUNTER="$2"

    PROCESS_DESC="$(printf "[%0${#MANIFEST_SIZE}d/%d]" "$JOB_COUNTER" "$MANIFEST_SIZE")"

    if is_reencoded "$FILENAME" ; then
        printf "${COLOUR_DONE}$PROCESS_DESC Skipping '%s', already re-encoded! (perc-gain was $(perc_gain "$FILENAME"))${COLOUR_CLEAR}\n" "$FILENAME" | tee -a "$LOG_F"
        return 0
    fi

    if reencode_was_attempted "$FILENAME" ; then
        printf "${COLOUR_WARNING}$PROCESS_DESC Skipping '%s', a re-encode attempt was already made (perc-gain was %s)${COLOUR_CLEAR}\n" "$FILENAME" "$(getfattr -n user.encode_attempt_gain "$FILENAME" 2>/dev/null)" | tee -a "$LOG_F"
        return 0
    fi
    
    if is_on_white_list "$FILENAME" ; then
        printf "${COLOUR_WHITELIST}$PROCESS_DESC Skipping '%s', it's on the white-list!${COLOUR_CLEAR}\n" "$FILENAME" | tee -a "$LOG_F"
        return 0
    fi
    
    if ! is_movie_file "$FILENAME" ; then
        printf "${COLOUR_NOT_MOVIE}$PROCESS_DESC Skipping '%s', not a movie!${COLOUR_CLEAR}\n" "$FILENAME" | tee -a "$LOG_F"
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

        if is_reencoded "$OUTF" ; then
            local GAIN="$(perc_gain "$OUTF")"
            if [ "$(echo "$GAIN > $PERC_THRESHOLD" | bc)" = "1" ] ; then
                # Here we do the switch-a-roo
                swap_files "$FILENAME" "$OUTF"
                
            else
                echo -e "${COLOUR_WARNING}reencode produced a gain of $GAIN; adding note (attribute) to '$FILENAME'${COLOUR_CLEAR}" | tee -a "$LOG_F"
                set_no_good_encode_xattr "$FILENAME" "$GAIN"
            fi
        else
            echo -e "${COLOUR_ERROR}For some reason, outfile='$OUTF' is not reencoded though!${COLOUR_CLEAR}" | tee -a "$LOG_F"
        fi

        return 0
    fi

    local CODEC="$(calc_codec "$FILENAME")"
    local BR="$(calc_bitrate "$FILENAME")"
    local WIDTH="$(calc_width "$FILENAME")"
    if [ "$CODEC" = "" ] || ! [ "$BR" -eq "$BR" 2>/dev/null ] || ! [ "$WIDTH" -eq "$WIDTH" 2>/dev/null ] ; then
        echo -e "${COLOUR_ERROR}$PROCESS_DESC [ERROR]${COLOUR_CLEAR} probe_info '$FILENAME' returned: "
        probe_info "$FILENAME" | tr '\n' ' '
        return 0
    fi

    if [ "$CODEC" = "$DESIRED_CODEC" ] && (( $BR <= $MAX_BITRATE )) && (( $WIDTH <= $MAX_W )); then        
        printf "${COLOUR_ALL_GOOD}$PROCESS_DESC Skipping %-80s (%s), bitrate less than $MAX_BITRATE, and width=${WIDTH} <= ${MAX_W}${COLOUR_CLEAR}\n" \
               "$FILENAME" \
               "$(print_info "$FILENAME")" \
            | tee -a "$LOG_F"
        return 0
    fi

    echo -e "${COLOUR_PROCESS}$PROCESS_DESC Transcoding '$FILENAME'${COLOUR_CLEAR}" | tee -a "$LOG_F"
    echo "   $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_F"

    local NOW="$(date '+%s')"
    if ! transcode_one "$FILENAME" ; then
        if [ "$KEEP_GOING" = "True" ] ; then
            return 0
        else
            exit 1
        fi
    fi
    set_encoded_xattr "$FILENAME" "$OUTF"

    local MINUTES="$(echo "scale=2 ; ($(date '+%s') - $NOW) / 60" | bc)"
    local DELTA="$(delta_megabytes "$FILENAME" "$OUTF")"
    update_total "$DELTA"

    PERC_GAIN="$(perc_gain "$OUTF")"
    
    echo "   Total Time:  $MINUTES minutes"                        | tee -a "$LOG_F"
    echo "   Output Info: $(print_info "$OUTF")"                   | tee -a "$LOG_F"
    echo "   Final Size:  $(du -sh "$OUTF" | awk '{ print $1 }')"  | tee -a "$LOG_F"
    echo "   Delta MiB:   $DELTA"                                  | tee -a "$LOG_F"
    echo "   Perc Gain:   $PERC_GAIN"                              | tee -a "$LOG_F"

    if [ "$(echo "$PERC_GAIN > $PERC_THRESHOLD" | bc)" = "1" ] ; then
        # Here we do the switch-a-roo
        echo "   Placing outfile in-situ" | tee -a "$LOG_F"
        swap_files "$FILENAME" "$OUTF"
                
    else
        echo "   Setting 'no-good-encode' xattr" | tee -a "$LOG_F"
        set_no_good_encode_xattr "$FILENAME" "$PERC_GAIN"
        
    fi

    
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

check_whitelist()
{
    # For every line in the white list:
    #  1. Check to see if the file exists in source
    #  2. Chcek to see if it's been transcoded...
    echo "0" > "$TMPD/exit_code"
    cat "$WHITELIST_F" | grep -Ev '^\#' | grep -Ev '^ *$' | while read FILENAME ; do
        OUT_F="$(output_filename "$FILENAME")"

        if [ ! -f "$INPUT_D/$FILENAME" ] ; then
            echo -e "${COLOUR_ERROR}FileNotFound${COLOUR_CLEAR}: $FILENAME"
            echo "1" > "$TMPD/exit_code"
        fi
        if [ -f "$OUT_F" ] ; then
            echo -e "${COLOUR_ERROR}TargetEncoded${COLOUR_CLEAR}: $OUT_F"
            echo "1" > "$TMPD/exit_code"
        fi
    done

    return "$(cat "$TMPD/exit_code")"
}

reconcile()
{
    echo "# Checking whitelist"
    ! check_whitelist | sed 's,^,   ,' && echo "fix issues with whitelist before continuing" 1>&2 && exit 1
    echo "# Checks done"

    D="$1"
    cd "$D"
    
    echo "0" > "$TMPD/exit_code"
    
    print_manifest > "$MANIFEST_F"
    MANIFEST_SIZE="$(cat "$MANIFEST_F" | wc -l)"

    COUNTER=1
    while read FILENAME ; do
        PROCESS_DESC="$(printf "[%0${#MANIFEST_SIZE}d/%d]" "$COUNTER" "$MANIFEST_SIZE")"
        COUNTER=$(expr $COUNTER + 1)

        if (( $COUNTER < 1130 )) || (( $COUNTER >= 1240 )) ; then
            continue
        fi

        if is_on_white_list "$FILENAME" ; then
            printf "# ${COLOUR_WHITELIST}$PROCESS_DESC Skipping '%s', it's on the white-list!${COLOUR_CLEAR}\n" "$FILENAME"
            continue
        fi
        
        if ! is_movie_file "$FILENAME" ; then
            printf "# ${COLOUR_NOT_MOVIE}$PROCESS_DESC Skipping '%s', not a movie!${COLOUR_CLEAR}\n" "$FILENAME"
            continue            
        fi
        
        local OUTF="$(output_filename "$FILENAME")"

        DESTD="$(dirname "$FILENAME")"
        DESTF="$DESTD/$(basename "$OUTF")"

        # printf "# ${COLOUR_PROCESS}$PROCESS_DESC Update '%s'${COLOUR_CLEAR}\n" "$FILENAME"
        
        if [ -f "$DESTF" ] && [ "$DESTF" != "$FILENAME" ] ; then
            # Have we already copied this file in?
            HASH1=$(md5sum "$OUTF"  | awk '{ print $1 }')
            HASH2=$(md5sum "$DESTF" | awk '{ print $1 }')
            if [ "$HASH1" = "$HASH2" ] ; then
                printf "# ${COLOUR_PROCESS}$PROCESS_DESC file reconciled but requires rm '%s'!${COLOUR_CLEAR}\n" "$FILENAME"
                echo "rm $(printf %q "$FILENAME")"
                echo ""
                continue
            fi
        fi

        if [ -f "$DESTF" ] && [ -f "$OUTF" ] && [ "$DESTF" = "$FILENAME" ] ; then
            HASH1=$(md5sum "$OUTF"  | awk '{ print $1 }')
            HASH2=$(md5sum "$DESTF" | awk '{ print $1 }')
            if [ "$HASH1" = "$HASH2" ] ; then
                printf "# ${COLOUR_ALL_GOOD}$PROCESS_DESC file already reconciled and is in-situ '%s'!${COLOUR_CLEAR}\n" "$FILENAME"
                continue
            fi
        fi
        
        if [ ! -f "$OUTF" ] ; then
            printf "# ${COLOUR_WARNING}$PROCESS_DESC File not processed '%s'${COLOUR_CLEAR}\n" "$FILENAME"
            continue
        fi

        printf "# ${COLOUR_PROCESS}$PROCESS_DESC creaing reconcile commands '%s'!${COLOUR_CLEAR}\n" "$FILENAME"
        
        echo "rm $(printf %q "$FILENAME")"
        echo "cp $(printf %q "$OUTF") $(printf %q "$DESTD")/"
        echo ""
        
    done < <(cat "$MANIFEST_F")

    EXITCODE="$(cat $TMPD/exit_code)"
    return "$EXITCODE"
}


# -- ACTRION! Check the Whitelist

if [ "$CHECK_WHITELIST" = "True" ] ; then
    check_whitelist
    echo "Checks done"
    exit $?
elif [ "$RECONCILE" = "True" ] ; then
    reconcile "$INPUT_D"
    exit $?
fi



# -- ACTION! Re-encode
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
