#!/bin/bash

echo "Disabled"
exit 1

SRCD=$HOME/Development/versions/cfs804
DSTD=$HOME/Development/SWG_NGP_kestrel

print_dirs()
{
    cat <<EOF
cfs/test
test
EOF
}

print_dirs | while read D ; do
    cd "$SRCD"
    find "$D" -type f | while read F ; do
        SRCF="$SRCD/$F"
        DSTF="$DSTD/$F"

        if [ "$(basename "$SRCF")" = ".DS_Store" ] ; then
            continue
        fi
           

        if [ ! -f "$DSTF" ] ; then
            echo "File not found: Dest file"
            continue
        fi
        
        diff -w -q "$SRCF" "$DSTF" 2>/dev/null 1>/dev/null && continue

        echo "------------------------------------------ $F"
        echo "cp $SRCF $DSTF"
        echo "--"
        diff -w "$SRCF" "$DSTF"
        echo
        echo
        echo
        
    done
done



