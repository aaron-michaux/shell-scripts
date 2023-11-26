#!/bin/bash

set -eu

PPWD="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." ; pwd -P)"

BAK_D="$HOME/TMP/zz-reencode"
TMPD=$(mktemp -d "/tmp/$(basename "$0").XXXXXX")
MAX_BITRATE=3000
MAX_COUNTER=0
DESIRED_CODEC="hevc"
CRF="23"
MAX_W="1024"

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

      Re-encodes a single video file, setting attributes along the way. The original video is 
      backed up to: '$BAK_D'

   Required Arguments

      -i <filename>        Input filename

   Options With Defaults      

      -c|--codec <codec>   The desired codec; default is $DESIRED_CODEC
      --crf <int>          Constant quality rate to use with codec; default is $CRF
      --max-bitrate <int>  Do not encode desired-codec videos with bitrate less than this; 
                           default is $MAX_BITRATE (kb/s)

   Other Options

      -p|--print           Print file information, including attributes, and exit
      --clear-errors       Clear error attributes, making the file available for re-encoding again

EOF
}

# -- Parse Command-line

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

INPUT_FILENAME=""
DO_PRINT="False"
DO_PRINT_BACKUP="False"
DO_CLEAR_ERRORS="False"
DO_SUMMARY="False"
DO_ENCODE="True"
while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "-i" ] && INPUT_FILENAME="$1" && shift && continue
    [ "$ARG" = "-c" ] || [ "$ARG" = "--code" ] && DESIRED_CODEC="$1" && shift && continue
    [ "$ARG" = "-crf" ] || [ "$ARG" = "--crf" ] && CRF="$1" && shift && continue
    [ "$ARG" = "-max-bitrate" ] || [ "$ARG" = "--max-bitrate" ] && MAX_BITRATE="$1" && shift && continue
    [ "$ARG" = "-p" ] || [ "$ARG" = "--print" ]   && DO_PRINT="True"   && DO_ENCODE="False" && continue
    [ "$ARG" = "-s" ] || [ "$ARG" = "--summary" ] && DO_SUMMARY="True" && DO_ENCODE="False" && continue
    [ "$ARG" = "-b" ] && DO_PRINT_BACKUP="True" && DO_ENCODE="False" && continue
    [ "$ARG" = "--clear-errors" ] && DO_CLEAR_ERRORS="True" && continue
    
    echo "Unexpected argument: '$ARG'" 1>&2 && exit 1
done

[ ! -f "$INPUT_FILENAME" ] && echo "input file not found: '$INPUT_FILENAME" 1>&2 && exit 1 || true

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

is_skip_encode()
{
    local FNAME="$1"
    getfattr -n user.skip_encode "$FNAME" 1>/dev/null 2>/dev/null && return 0 || return 1
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

size_diff()
{
    local FNAME="$1"
    
    # This only makes sense for reencoded files
    is_reencoded "$FNAME" || return 1

    local SZ_0="$(getfattr -d "$FNAME" 2>/dev/null | grep "user.original_filesize" | awk -F= '{ print $2 }' | sed 's,",,g')"
    local SZ_1="$(du -b "$FNAME" | awk '{ print $1 }')"
    local DIFF="$(echo "scale=9 ; ($SZ_0 - $SZ_1)" | bc)"
    local UNITS="bytes"

    if [ "$(echo "$DIFF > 1024" | bc)" = "1" ] ; then
        UNITS="KiB"
        DIFF="$(echo "scale=9 ; $DIFF / 1024.0" | bc)"
    fi
    if [ "$(echo "$DIFF > 1024" | bc)" = "1" ] ; then
        UNITS="MiB"
        DIFF="$(echo "scale=9 ; $DIFF / 1024.0" | bc)"
    fi
    if [ "$(echo "$DIFF > 1024" | bc)" = "1" ] ; then
        UNITS="GiB"
        DIFF="$(echo "scale=9 ; $DIFF / 1024.0" | bc)"
    fi

    if [ "$UNITS" != "bytes" ] ; then
        DIFF="$(echo "scale=3 ; $DIFF / 1" | bc)"
    fi
    echo "$DIFF $UNITS"
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

homefilename()
{
    local FILENAME="$1"
    local ABSFNAME="$(absfilename "$FILENAME")"
    if [ "${ABSFNAME:0:$(expr ${#HOME} + 1)}" = "$HOME/" ] ; then
        echo "${ABSFNAME:$(expr ${#HOME} + 1)}"
    else
        echo "$ABSFNAME"
    fi
}

output_base_filename()
{
    local FILENAME="$1"
    echo "$(cd "$(dirname "$FILENAME")" ; pwd -P)/$(extensionless "$(basename "$FILENAME")").mp4"
}

tmp_filename()
{
    local FILENAME="$1"
    echo "$TMPD/$(basename "$(output_base_filename "$FILENAME")")"
}

backup_filename()
{
    local FILENAME="$1"
    echo "$BAK_D/$(output_base_filename "$FILENAME")"
}

output_filename()
{
    local FILENAME="$1"
    echo "$(output_base_filename "$FILENAME")"
}

# -- Movie info

cached_info()
{
    local FILENAME="$1"
    local DATAF="$(extensionless "$TMPD/$FILENAME")._ci"    
    if [ ! -f "$DATAF" ] ; then
        mkdir -p "$(dirname "$DATAF")"
        local FILE_SIZE="$(du -b "$FILENAME" | awk '{ print $1 }')"
        IS_MOVIE="True"
        local EXT="$(extension "$FILENAME")"
        echo "filename=$(homefilename "$FILENAME")"             > "$DATAF"
        echo "bytes=$FILE_SIZE"                                >> "$DATAF"
        transcode.sh -i "$FILENAME" --info                     >> "$DATAF" || IS_MOVIE="False"
        local CODEC="$(cat "$DATAF" | grep -E "^codec_name=" | awk -F= '{ print $2 }')"        
        local DURATION="$(cat "$DATAF" | grep -E "^duration=" | awk -F= '{ print $2 }')"
        if [ "$CODEC" = "ansi" ] ; then
            IS_MOVIE="False"
        elif [ "$CODEC" = "mjpeg" ] ; then
            if [ "$DURATION" = "N/A" ] || [ "$FILE_SIZE" -lt "4194304" ] ; then
                IS_MOVIE="False"               
            fi
        elif [ "$CODEC" = "" ] ; then
            IS_MOVIE="False"
        elif [ "$EXT" = "mp3" ] ; then
            IS_MOVIE="False"            
        elif [ "$EXT" = "png" ] ; then
            IS_MOVIE="False"            
        fi
        echo "is_movie=$IS_MOVIE"                               >> "$DATAF"
        echo "is_reencoded=$(is_reencoded "$FILENAME" && echo "True" || echo "False")" >> "$DATAF"
        echo "size_diff=$(size_diff "$FILENAME" || echo "")"    >> "$DATAF"
        echo "percent_gain=$(perc_gain "$FILENAME" || echo "")" >> "$DATAF"
    fi
    cat "$DATAF"
}

is_movie_file()
{
    local FILENAME="$1"
    cached_info "$FILENAME" | grep -qE "^is_movie=True" && return 0 || return 1
}

set_is_movie_xattr()
{
    local FILENAME="$1"
    setfattr -n user.is_movie -v "$(is_movie_file "$FILENAME" && echo "True" || echo "False")" "$FILENAME"
}

lazy_is_movie_file()
{
    local FILENAME="$1"
    VALUE="$(getfattr -n user.is_movie "$FILENAME" 2>/dev/null | grep user.is_movie || true)"
    if [ "$VALUE" = "" ] ; then
        set_is_movie_xattr "$FILENAME"
        lazy_is_movie_file "$FILENAME" && return 0 || return 1
    fi   
    [ "$VALUE" = "user.is_movie=\"True\"" ] && return 0 || return 1
}

probe_info()
{
    local FILENAME="$1"
    cached_info "$FILENAME"
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
    printf "%s %s kb/s %dx%d %s"  \
           "$(calc_codec "$F")"   \
           "$(calc_bitrate "$F")" \
           "$(calc_width "$F")"   \
           "$(calc_height "$F")"  \
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

# -- Transcoding

print_transcode_cmd()
{
    local FILE="$1"
    local TMPF="$2"
    echo -n "transcode.sh -i $(printf %q "$FILE") --crf $CRF --${DESIRED_CODEC} --mw $MAX_W $(printf %q "$TMPF")"
}

transcode_one()
{
    local FILE="$1"

    local NOW="$(date '+%s')"
    local TEMP_F="$(tmp_filename "$FILE")"
    local OUT_F="$(output_filename "$FILE")"
    
    mkdir -p "$(dirname "$TEMP_F")"    
    print_transcode_cmd "$FILE" "$TEMP_F" | sed 's,^,   ,'
    print_transcode_cmd "$FILE" "$TEMP_F" | dash && SUCCESS="True" || SUCCESS="False"
    if [ "$SUCCESS" != "True" ] ; then
        return 1
    fi
    
    set_encoded_xattr "$FILE" "$TEMP_F"

    local MINUTES="$(echo "scale=2 ; ($(date '+%s') - $NOW) / 60" | bc)"
    local DELTA="$(delta_megabytes "$FILE" "$TEMP_F")"
    local PERC_GAIN="$(perc_gain "$TEMP_F")"
    
    echo "   Total Time:  $MINUTES minutes"
    echo "   Output Info: $(print_info "$TEMP_F")"
    echo "   Final Size:  $(du -sh "$TEMP_F" | awk '{ print $1 }')"
    echo "   Delta MiB:   $DELTA"
    echo "   Perc Gain:   $PERC_GAIN"

    if [ "$(echo "$PERC_GAIN > $PERC_THRESHOLD" | bc)" = "1" ] ; then
        # Here we do the switch-a-roo
        local BACK_F="$(backup_filename "$FILE")"
        mkdir -p "$(dirname "$BACK_F")"
        mv "$FILE" "$BACK_F"
        mv "$TEMP_F" "$OUT_F"
        
    else
        echo "   Setting 'no-good-encode' xattr"
        set_no_good_encode_xattr "$FILE" "$PERC_GAIN"
        
    fi
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

set_skip_encode_xattr()
{
    local FILENAME="$1"
    local REASON="$2"
    setfattr -n user.skip_encode -v "$REASON" "$FILENAME"
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
    local DO_SUMMARY="$2"
    JOB_COUNTER="0"

    PROCESS_DESC=""

    if is_reencoded "$FILENAME" ; then
        printf "${COLOUR_DONE}${PROCESS_DESC}already done, filename: %s, perc-gain %s${COLOUR_CLEAR}\n" "$FILENAME" "$(perc_gain "$FILENAME")"        
        return 0
    fi

    if reencode_was_attempted "$FILENAME" ; then
        printf "${COLOUR_WARNING}${PROCESS_DESC}re-encode attempt was already made, filename: %s, perc-gain %s${COLOUR_CLEAR}\n" "$FILENAME" "$(getfattr -n user.encode_attempt_gain "$FILENAME" 2>/dev/null)"
        return 0
    fi

    if is_skip_encode "$FILENAME" ; then
        printf "${COLOUR_DONE}${PROCESS_DESC}skip encode, filename: %s, reason: %s${COLOUR_CLEAR}\n" "$FILENAME" "$(getfattr -n user.skip_encode "$FILENAME" 2>/dev/null | awk -F= '{ print $2 }' | tr '\n' ' ' | sed 's,^ *",,' | sed 's," *$,,' )"
        return 0
    fi
        
    if ! lazy_is_movie_file "$FILENAME" ; then
        printf "${COLOUR_NOT_MOVIE}${PROCESS_DESC}not a movie, filename: %s${COLOUR_CLEAR}\n" "$FILENAME"
        return 0
    fi

    local BACK_F="$(backup_filename "$FILENAME")"
    
    if [ -f "$BACK_F" ] ; then
        echo -e "${COLOUR_ERROR}cowardly refusing to encode '$FILENAME' because backup-file '$BACK_F' already exists${COLOUR_CLEAR}"
        return 0
    fi
    
    local CODEC="$(calc_codec "$FILENAME")"
    local BR="$(calc_bitrate "$FILENAME")"
    local WIDTH="$(calc_width "$FILENAME")"
    if [ "$CODEC" = "" ] || ! [ "$BR" -eq "$BR" 2>/dev/null ] || ! [ "$WIDTH" -eq "$WIDTH" 2>/dev/null ] ; then
        echo -e "${COLOUR_ERROR}${PROCESS_DESC}[error]${COLOUR_CLEAR} probe_info '$FILENAME' returned: "
        probe_info "$FILENAME" | tr '\n' ' '
        echo
        echo "CODEC = '$CODEC'; BR = '$BR'; WIDTH = '$WIDTH'"
        echo
        set_skip_encode_xattr "$FILENAME" "could not determine encode variables"
        return 1
    fi

    if [ "$CODEC" = "$DESIRED_CODEC" ] && (( $BR <= $MAX_BITRATE )) && (( $WIDTH <= $MAX_W )) ; then        
        printf "${COLOUR_ALL_GOOD}${PROCESS_DESC}all good, filename: %s, bitrate: %s <= %s, width: %s <= %s\n" "$FILENAME" "$BR" "$MAX_BITRATE" "$WIDTH" "$MAX_W"
        set_skip_encode_xattr "$FILENAME" "all good"                  
        return 0
    fi

    echo -e "${COLOUR_PROCESS}${PROCESS_DESC}transcoding $FILENAME${COLOUR_CLEAR}"

    if [ "$DO_SUMMARY" = "True" ] ; then
        # Prepare to reencode
        local TEMP_F="$(tmp_filename "$FILENAME")"    
        mkdir -p "$(dirname "$BACK_F")"
        mkdir -p "$(dirname "$TEMP_F")"       
       
        echo "   $(date '+%Y-%m-%d %H:%M:%S')"

        if ! transcode_one "$FILENAME" ; then
            exit 1
        fi
    fi
}

if [ "$DO_CLEAR_ERRORS" = "True" ] ; then
    setfattr --remove=user.is_movie            "$INPUT_FILENAME" 2>/dev/null || true
    setfattr --remove=user.skip_encode         "$INPUT_FILENAME" 2>/dev/null || true
    setfattr --remove=user.encode_attempt_date "$INPUT_FILENAME" 2>/dev/null || true
    setfattr --remove=user.encode_attempt_gain "$INPUT_FILENAME" 2>/dev/null || true
fi

if [ "$DO_PRINT_BACKUP" = "True" ] ; then
    backup_filename "$INPUT_FILENAME"
fi

if [ "$DO_PRINT" = "True" ] ; then
    if lazy_is_movie_file "$INPUT_FILENAME" ; then
        getfattr -d -m - "$INPUT_FILENAME"
        echo "Info-line: $(print_info "$INPUT_FILENAME")"
        echo
        cached_info "$INPUT_FILENAME"
        echo
    fi
fi

if [ "$DO_ENCODE" = "True" ] || [ "$DO_SUMMARY" = "True" ] ; then
    # -- ACTION! Re-encode (or do summary)
    examine_one "$INPUT_FILENAME" "$DO_SUMMARY"
fi

