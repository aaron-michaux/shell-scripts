#!/bin/bash

set -o errexit -o noclobber -o nounset -o pipefail

CODEC=libmp3lame
EXTENSION=mp3
MODE=chaptered

show_help()
{
    cat <<EOF

   Usage: bash AAXtoMP3.sh [--flac] [--single] AUTHCODE {FILES}"

      AUTHCODE can be saved to ~/.aax-authcode

EOF
}

[ "$#" -eq 0 ] && show_help && exit 1

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

if [[ "$1" = '--flac' ]]
then
    CODEC=flac
    EXTENSION=flac
    shift
fi

if [[ "$1" == '--single' ]]
then
    MODE=single
    shift
fi

if [ ! -f ~/.aax-authcode ]; then
    AUTH_CODE=$1
    shift
else
    AUTH_CODE=`head -1 ~/.aax-authcode`
fi

debug()
{
    echo "$(date "+%F %T%z") ${1}"
}

trap 'rm -rf "${WORKING_DIRECTORY}"' EXIT
WORKING_DIRECTORY=`mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir'`
METADATA_FILE="${WORKING_DIRECTORY}/metadata.txt"

save_metadata()
{
    local media_file
    media_file="$1"
    ffprobe -i "$media_file" 2> "$METADATA_FILE"
}

get_metadata_value()
{
    local KEY
    KEY="$1"
    normalize_whitespace "$(grep --max-count=1 --only-matching "${KEY} *: .*" "$METADATA_FILE" | cut -d : -f 2 | sed -e 's#/##g;s/ (Unabridged)//' | tr -s '[:blank:]' ' ')"
}

get_bitrate()
{
    get_metadata_value bitrate | grep --only-matching '[0-9]\+'
}

normalize_whitespace()
{
    echo $*
}

for path
do
    debug "Decoding ${path} with auth code ${AUTH_CODE}..."

    save_metadata "${path}"
    GENRE=$(get_metadata_value genre)
    ARTIST=$(get_metadata_value artist)
    TITLE=$(get_metadata_value title)
    OUTPUT_DIRECTORY="$(dirname "${path}")/${TITLE}"
    mkdir -p "${OUTPUT_DIRECTORY}"
    FULL_FILE_PATH="${OUTPUT_DIRECTORY}/${TITLE}.${EXTENSION}"

    nice ionice -c3 ffmpeg -nostdin -loglevel error -stats -activation_bytes "${AUTH_CODE}" -i "${path}" -vn -codec:a "${CODEC}" -ab "$(get_bitrate)k" -map_metadata -1 -metadata title="${TITLE}" -metadata artist="${ARTIST}" -metadata album_artist="$(get_metadata_value album_artist)" -metadata album="$(get_metadata_value album)" -metadata date="$(get_metadata_value date)" -metadata track="1/1" -metadata genre="${GENRE}" -metadata copyright="$(get_metadata_value copyright)" "${FULL_FILE_PATH}"

    debug "Created ${FULL_FILE_PATH}."

    if [ "${MODE}" == "chaptered" ]; then
        debug "Extracting chapter files from ${FULL_FILE_PATH}..."

        while read -r -u9 first _ _ start _ end
        do
            if [[ "${first}" = "Chapter" ]]
            then
                read -r -u9 _
                read -r -u9 _ _ CHAPTER
                CHAPTER2="$(printf %02d "$(echo "${CHAPTER}" | sed 's,[^0-9],,g')")"
                CHAPTER1="$(echo $CHAPTER2 | sed 's,^0*,,')"
                CHAPTER_FILE="${OUTPUT_DIRECTORY}/${TITLE} - Chapter ${CHAPTER2}.${EXTENSION}"
                nice ionice -c3 ffmpeg -nostdin -loglevel error -stats -i "${FULL_FILE_PATH}" -ss "${start%?}" -to "${end}" -codec:a copy -metadata track="${CHAPTER}" "${CHAPTER_FILE}"
                id3v2 -t "$CHAPTER2 - ${TITLE}" -A "${TITLE}" -a "${ARTIST}" -T "$(printf %d "$CHAPTER1")" "$CHAPTER_FILE"
                
            fi
        done 9< "$METADATA_FILE"
        rm "${FULL_FILE_PATH}"
        debug "Done creating chapters. Chaptered files contained in ${OUTPUT_DIRECTORY}."
    fi

    COVER_PATH="${OUTPUT_DIRECTORY}/cover.jpg"
    debug "Extracting cover into ${COVER_PATH}..."
    ffmpeg -nostdin -loglevel error -activation_bytes "${AUTH_CODE}" -i "${path}" -an -codec:v copy "${COVER_PATH}"
    debug "Done."
    rm "${METADATA_FILE}"
done

