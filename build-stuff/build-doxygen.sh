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

      # Install doxygen 1.9.5 to $TOOLS_DIR/bin
      > $(basename $0) 1.9.5

   Repos:

      https://github.com/doxygen/doxygen

EOF
}

# --------------------------------------------------------------------- valgrind

build_doxygen()
{
    VERSION="$1"
    VERSION_TAG="$(echo "$VERSION" | sed 's,\.,_,g')"

    cd "$TMPD"
    if [ ! -d doxygen ] ; then
        git clone https://github.com/doxygen/doxygen
    fi
    cd doxygen
    git fetch
    git checkout Release_${VERSION_TAG}
    rm -rf build
    mkdir build
    cd build    
    
    export CC="$HOST_CC"
    export CXX="$HOST_CXX"
    export CFLAGS="-fPIC -O3 -isystem$LLVM_DIR/include"
    export CXXFLAGS="-fPIC -O3 -isystem$LLVM_DIR/include"
    export LDFLAGS="-L$LLVM_DIR/lib -Wl,-rpath,$LLVM_DIR/lib"

    # export CMAKE_PREFIX_PATH=$TOOLS_DIR
    $CMAKE -D CMAKE_BUILD_TYPE=Release             \
           -D english_only=ON                      \
           -D build_doc=OFF                        \
           -D build_wizard=ON                      \
           -D build_search=ON                      \
           -D build_xmlparser=ON                   \
           -D CMAKE_INSTALL_PREFIX:PATH=$TOOLS_DIR \
           ..

    make -j
    make install
}


# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "False" "$@"

# ----------------------------------------------------------------------- action

if [ "$ACTION" != "" ] ; then
    ensure_directory "$TOOLS_DIR"
    install_dependences
    build_doxygen $ACTION
fi


