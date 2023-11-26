#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"

WHITELIST_F=""
TMPD=$(mktemp -d "/tmp/$(basename "$0").XXXXXX")
MAX_BITRATE=3000
MAX_COUNTER=0
DESIRED_CODEC="hevc"
CRF="23"
MAX_W="1024"
KEEP_GOING="False"

CHECK_WHITELIST="False"
RECONCILE="False"
PRINT_DATABASE="False"

TOTALS_F="$TMPD/totals"
TRANSCODED_COUNTER_F="$TMPD/transcoded_counter"
MANIFEST_F="$TMPD/manifest.text"
MANIFEST_SIZE=0
INPUT_DIR_FILE="$TMPD/inputs"

COLOUR_ERROR='\e[0;91m'
COLOUR_WHITELIST='\e[0;97m'
COLOUR_WARNING='\e[0;93m'
COLOUR_DONE='\e[0;94m'
COLOUR_PROCESS='\e[0;92m'
COLOUR_ALL_GOOD="\e[0;96m"
COLOUR_NOT_MOVIE="\e[0;90m"
COLOUR_CLEAR='\e[0;0m'

PERC_THRESHOLD="20.0"

declare -A WHITELIST_SET
WHITELIST_SET[z]=1

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

      -i <path>           An input directory, can be specified multiple times
      -o <path>           Output directory

   Options With Defaults      

      -c|--codec <codec>  The desired codec; default is $DESIRED_CODE
      --crf <int>         Constant quality rate to use with codec; default is $CRF
      --max-bitrate <int> Do not encode desired-codec videos with bitrate less than this; default i $MAX_BITRATE (kb/s)
      -k                  Keep going if there's an error

   Utility Options

      -w <filename>       A white-list file, where each line lists a video file to skip; filenames
                          are always relative to the user's home directory.

      --check-whitelist   Check the passed whitelist:
                           1. Do any files in the whitelist not exist in source?

      --reconcile         Movies files back from the encode directory to the source directory,
                          removing source files. (cp/rsync cannot be used because of file name changes.)
  
      --print-database    Prints our (csv) format data

EOF
}

# -- Parse Command-line

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

touch "$INPUT_DIR_FILE"
while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "-i" ] && echo "$1" >> "$INPUT_DIR_FILE" && shift && continue
    [ "$ARG" = "-w" ] && WHITELIST_F="$1" && shift && continue
    [ "$ARG" = "-c" ]   || [ "$ARG" = "--code" ] && DESIRED_CODEC="$1" && shift && continue
    [ "$ARG" = "-crf" ] || [ "$ARG" = "--crf"  ] && CRF="$1"           && shift && continue
    [ "$ARG" = "-max-bitrate" ] || [ "$ARG" = "--max-bitrate" ] && MAX_BITRATE="$1" && shift && continue
    [ "$ARG" = "-k" ]                && KEEP_GOING="True" && continue
    [ "$ARG" = "--check-whitelist" ] && CHECK_WHITELIST="True" && continue
    [ "$ARG" = "--reconcile" ]       && RECONCILE="True" && continue
    [ "$ARG" = "--print-database" ]  && PRINT_DATABASE="True" && continue
    echo "Unexpected argument: '$ARG'" 1>&2 && exit 1
done

# -- Input directories

input_directories() {
    cat "$INPUT_DIR_FILE" | sed 's,/$,,'
}

[ -f "$HOME/TMP" ] && LOG_F="$HOME/TMP/reencode-log.text" || LOG_F="/tmp/reencode-log.text"

# -- File info



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

# ---------------------------------------------------------------------------------- encode filename

encode_filename()
{
    echo "$1" | sha256sum | cut -f 1 -d ' '
}

# --------------------------------------------------------------------------------- is on white list

is_on_white_list()
{
    local FILENAME="$(encode_filename "$1")"
    [ -v WHITELIST_SET[$FILENAME] ] && return 0 || return 1
}

# --------------------------------------------------------------------- printing the entire manifest

print_manifest()
{
    if [ ! -f "$TMPD/manifest.text" ] ; then
        while read DIR ; do
            find "$DIR" -type f | sed 's,^./,,' | sort
        done < <(input_directories) > "$TMPD/manifest.text"
    fi
    cat "$TMPD/manifest.text"
}

# --------------------------------------------------------------------------- printing the whitelist

print_whitelist()
{
    if [ -f "$WHITELIST_F" ] ; then
        cat "$WHITELIST_F" | grep -Ev '^\#' | grep -Ev '^ *$'
    fi
}

# ---------------------------------------------------------------------------------- check whitelist

check_whitelist()
{
    # For every line in the white list:
    #  1. Check to see if the file exists in source
    echo "0" > "$TMPD/exit_code"
    cat "$WHITELIST_F" | grep -Ev '^\#' | grep -Ev '^ *$' | while read FILENAME ; do
        if [ "$FILENAME" != "" ] && [ ! -f "$FILENAME" ] ; then
            echo -e "${COLOUR_ERROR}FileNotFound${COLOUR_CLEAR}: $FILENAME"
            echo "1" > "$TMPD/exit_code"
        fi
    done < <(print_whitelist ; echo)
    return "$(cat "$TMPD/exit_code")"
}

# ----------------------------------------------------------------------------------- print database

print_database()
{
    IS_FIRST="True"
    while read FILENAME ; do
        INFO="$($SCRIPT_DIR/zencode.sh -i "$FILENAME" -p)"
        if [ "$INFO" != "" ] ; then
            if [ "$IS_FIRST" = "True" ] ; then
                IS_FIRST="False"
                echo -n "filename,"
                echo "$INFO" | sed '0,/^filename=/d' | awk -F= '{ print $1 }' | grep -Ev '^ *$' | tr '\n' ',' | sed 's/,$//'
                echo
            fi
            
            FIELDS="$(echo "$INFO" | sed '0,/^filename=/d' | awk -F= '{ print $2 }' | grep -Ev '^ *$' | tr '\n' ',' | sed 's/,$//')"
            printf '"%s",%s\n' "$FILENAME" "$FIELDS"
        fi
    done < <(print_manifest)
}

# --------------------------------------------------------------------------------- process manifest

ALREADY_DONE=0
REENCODE_ALREADY_ATTEMPTED=0
SKIP_ENCODE=0
NOT_A_MOVIE=0
BACKUP_FILE_ALREADY_EXISTS=0
ALL_GOOD=0   # The file didn't need to be transcoded
TRANSCODED=0
UNCATEGORIZED=0

ERROR_COUNT=0
WHITELIST_COUNT=0

process_manifest()
{
    MANIFEST_SIZE="$(print_manifest | wc -l)"
    MANIFEST_DIGITS=${#MANIFEST_SIZE}
    
    # 1-index counter to be human readable
    COUNTER=1
    while read FILENAME ; do

        printf "[%0${MANIFEST_DIGITS}d/%0${MANIFEST_DIGITS}d] " $COUNTER $MANIFEST_SIZE  | tee -a "$LOG_F"
        if is_on_white_list "$FILENAME" ; then
            printf "${COLOUR_WHITELIST}white-list, filename: %s${COLOUR_CLEAR}\n" "$FILENAME" | tee -a "$LOG_F"
            WHITELIST_COUNT=$(expr $WHITELIST_COUNT + 1)
        else
            "$SCRIPT_DIR/zencode.sh" -i "$FILENAME" | tee -a "$LOG_F" | tee "$TMPD/output" \
                && SUCCESS="True" || SUCCESS="False"

            OUTPUT="$(cat "$TMPD/output")"
            if [ "$SUCCESS" = "False" ] ; then
                ERROR_COUNT=$(expr $ERROR_COUNT + 1)
            elif [[ "$OUTPUT" =~ already\ done ]] ; then
                ALREADY_DONE=$(expr $ALREADY_DONE + 1)
            elif [[ "$OUTPUT" =~ re-encode\ attempt\ was\ already\ made ]] ; then
                REENCODE_ALREADY_ATTEMPTED=$(expr $REENCODE_ALREADY_ATTEMPTED + 1)
            elif [[ "$OUTPUT" =~ skip\ encode ]] ; then
                SKIP_ENCODE=$(expr $SKIP_ENCODE + 1)
            elif [[ "$OUTPUT" =~ not\ a\ movie ]] ; then
                NOT_A_MOVIE=$(expr $NOT_A_MOVIE + 1)
            elif [[ "$OUTPUT" =~ cowardly\ refusing\ to\ encode ]] ; then
                BACKUP_FILE_ALREADY_EXISTS=$(expr $BACKUP_FILE_ALREADY_EXISTS + 1)
            elif [[ "$OUTPUT" =~ all\ good\,\ filename ]] ; then
                ALL_GOOD=$(expr $ALL_GOOD + 1)
            elif [[ "$OUTPUT" =~ transcoding\  ]] ; then
                TRANSCODED=$(expr $TRANSCODED + 1)
            else
                echo "\nFELL THROUGH THE CRACKS OUTPUT=$OUTPUT\n" | tee -a "$LOG_F"
                UNCATEGORIZED=$(expr $UNCATEGORIZED + 1)
            fi
        fi
        
        COUNTER=$(expr $COUNTER + 1)        
    done  < <(print_manifest)
}

# -- Sanity checks

[ "$(input_directories | wc -l)" = "0" ] \
    && echo "Must specify an input directory" 1>&2 && exit 1 || true

HAS_ERROR="False"
while read DIR ; do
    [ ! -d "$DIR" ] && echo "Input directory not found: '$DIR'" 1>&2 && HAS_ERROR="True" || true
done < <(input_directories)
[ "$HAS_ERROR" = "True" ] && exit 1 || true

[ "$WHITELIST_F" != "" ] && [ ! -f "$WHITELIST_F" ] \
    && echo "Whitelist file not found: '$WHITELIST_F'" 1>&2 && exit 1 || true

# -- Setup whitelist if it exists

while read LINE ; do
    WHITELIST_SET[$(encode_filename "$LINE")]=1
done < <(print_whitelist)

# -- ACTION! Check the Whitelist

if [ "$CHECK_WHITELIST" = "True" ] ; then
    check_whitelist
    echo "Checks done"
    exit $?
elif [ "$RECONCILE" = "True" ] ; then
    reconcile "$INPUT_D"
    exit $?
elif [ "$PRINT_DATABASE" = "True" ] ; then
    print_database
    exit $?
fi

# -- ACTION! Re-encode

mkdir -p "$(dirname "$LOG_F")"    
printf '\n\n\n# --------------------------------------------- START (%s)\n' "$(date)" | tee "$LOG_F"
while read DIR ; do
    echo "Directory:        $DIR"     | tee "$LOG_F"
done < <(input_directories)
echo "Whitelist file:   $WHITELIST_F" | tee "$LOG_F"
echo "Log file:         $LOG_F"       | tee "$LOG_F"
process_manifest

cat <<EOF

Already reencoded:          $ALREADY_DONE
Encode not necessary:       $ALL_GOOD
Transcoded:                 $TRANSCODED
Prev reencode didn't help:  $REENCODE_ALREADY_ATTEMPTED
Skipped encode:             $SKIP_ENCODE
Was on whitelist:           $WHITELIST_COUNT

Not a movie:                $NOT_A_MOVIE
Backup already existed:     $BACKUP_FILE_ALREADY_EXISTS
Errors:                     $ERROR_COUNT
Uncategorized:              $UNCATEGORIZED

Total Saved:                $(echo "scale=3 ; $(get_total) / 1024" | bc) Gigs

EOF

