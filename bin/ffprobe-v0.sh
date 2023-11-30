#!/bin/bash

TMPF="$(mktemp /tmp/$(basename "$0").XXXXXX)"
trap cleanup EXIT
cleanup()
{
    rm -rf "$TMPF"
}

FILENAME="$1"

if [ ! -f "$FILENAME" ] ; then
    echo "File not found '$FILENAME'" 1>&2
    exit 1
fi

ffprobe -v error -hide_banner -of default=noprint_wrappers=0 -print_format flat -show_entries stream=bit_rate,codec_name,duration,width,height,pix_fmt -sexagesimal "$FILENAME" 2>/dev/null > "$TMPF"


for STREAM_NUMBER in $(cat "$TMPF" | awk -F. '{ print $3 }' | sort | uniq | tr '\n' ' ') ; do
    echo "streams.stream.$STREAM_NUMBER"
    cat "$TMPF" | grep -E "^streams.stream.$STREAM_NUMBER" | sed "s,^streams.stream.$STREAM_NUMBER.,   ,"
done
