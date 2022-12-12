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
      --toolchain <value>  Must be a toolchain built with 'build-toolchain.sh'
      --env                Print script environment variables

   Examples:

      # Install google test
      > $(basename $0) 1.12.1

   Repos:

      https://github.com/google/googletest

EOF
}

# --------------------------------------------------------------------- valgrind

build_google_test()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d googletest ] ; then
        git clone https://github.com/google/googletest.git
    fi
    cd googletest
    git fetch
    git checkout release-${VERSION}    
    rm -rf build
    mkdir build
    cd build

    $CMAKE -D CMAKE_INSTALL_PREFIX:PATH=$PREFIX   \
           ..

    make -j$(nproc)
    make install
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "UseToolchain" "$@"

# ----------------------------------------------------------------------- action

if [ "$ACTION" != "" ] ; then
    ensure_directory "$TOOLS_DIR"
    install_dependences
    build_google_test $ACTION
fi

