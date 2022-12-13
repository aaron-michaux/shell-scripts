#!/bin/bash

set -e

source "$(cd "$(dirname "$0")" ; pwd)/env.sh"

show_help()
{
    cat <<EOF

   Usage: $(basename $0) OPTION* <version>

   Option:

      --cleanup            Remove temporary files after building
      --no-cleanup         Do not remove temporary files after building
      --env                Print script environment variables

   Examples:

      # Install valgrind 3.20 to $TOOLS_DIR/bin
      > $(basename $0) 3.20.0

   Repos:

      http://www.valgrind.org/downloads

EOF
}

# --------------------------------------------------------------------- valgrind

build_valgrind()
{
    VALGRIND_VERSION="$1"
    URL="https://sourceware.org/pub/valgrind/valgrind-${VALGRIND_VERSION}.tar.bz2"
    VAL_D="$TMPD/valgrind-${VALGRIND_VERSION}"
    rm -rf "$VAL_D"
    cd "$TMPD"
    wget "$URL"
    bzip2 -dc valgrind-${VALGRIND_VERSION}.tar.bz2 | tar -xf -
    rm -f valgrind-${VALGRIND_VERSION}.tar.bz2
    cd "$VAL_D"
    export CC=$HOST_CC
    export CXX=$HOST_CXX
    ./autogen.sh
    ./configure --prefix="$TOOLS_DIR"
    nice make -j$(nproc)
    make install
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "False" "$@"

# ----------------------------------------------------------------------- action

if [ "$ACTION" != "" ] ; then
    ensure_directory "$TOOLS_DIR"
    install_dependences
    build_valgrind $ACTION
fi

