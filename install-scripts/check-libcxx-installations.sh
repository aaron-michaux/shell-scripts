#!/bin/bash

set -e

show_help()
{
    cat <<EOF

   Usage: $(basename $0)

   Checks libcxx installations for any stray erroneous linking to libstdc++

EOF
}

WORKING_DIR="$(cd "$(dirname "$0")" ; pwd)"
cd "$WORKING_DIR"
source "./env.sh"

find_installations()
{
    find "$ARCH_DIR" -maxdepth 1 -type d -name '*_libcxx' | sort
}

check_installation()
{
    RET_CODE="0"
    find -L "$DIR" -type l -o -type f -name '*.so' | while read FILE ; do
        lddtree "$FILE" | grep -q "libstdc++" && SUCCESS="False" || SUCCESS="True"
        if [ "$SUCCESS" = "False" ] ; then
            echo "Error: $FILE links to libstdc++"
            RET_CODE="1"
        fi
    done
    return "$RET_CODE"
}

EXIT_CODE="0"
find_installations | while read DIR ; do    
    if check_installation "$DIR" ; then
        echo "PASS: $DIR"
    else
        EXIT_CODE="1"
    fi
done

exit "$EXIT_CODE"

