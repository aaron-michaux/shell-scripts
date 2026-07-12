#!/bin/bash

show_help() {
    cat <<EOF

    Usage: $(basename "$0") <container-name>

EOF
}

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

[ "$#" != "1" ] && show_help && exit 1

CONTAINER_NAME="$1"
docker exec -it "$CONTAINER_NAME" /bin/bash
