#!/bin/bash

set -e

source "$(cd "$(dirname "$0")" ; pwd)/env.sh"

show_help()
{
    cat <<EOF

   Usage: $(basename $0) OPTION* <version>

   Options:

$(show_help_snippet)

   Examples:

      # Install using 'gcc'
      > $(basename $0) --toolchain=gcc --version=1.80.0

   Repos:

      https://www.boost.org/

EOF
}


with_libraries()
{
    cat <<EOF
--with-contract
--with-date_time
--with-fiber
--with-headers
--with-json
--with-program_options
--with-python
--with-serialization
--with-stacktrace
--with-system
EOF
}


without_libraries()
{
    cat <<EOF
--without-atomic
--without-chrono
--without-container
--without-context
--without-coroutine
--without-exception
--without-filesystem
--without-graph
--without-graph_parallel
--without-iostreams
--without-locale
--without-log
--without-math
--without-mpi
--without-nowide
--without-random
--without-regex
--without-test
--without-thread
--without-timer
--without-type_erasure
--without-wave
EOF
}

# ------------------------------------------------------------------------ build

build()
{
    VERSION="$1"

    cd "$TMPD"

    DIR="boost_$(echo "$VERSION" | sed 's,\.,_,g')"
    TAR_F="$DIR.tar.bz2"
    if [ ! -f "$TAR_F" ] ; then
        URL="https://boostorg.jfrog.io/artifactory/main/release/$VERSION/source/$TAR_F"
        wget "$URL"
    fi
    if [ ! -d "$DIR" ] ; then
        cat "$TAR_F" | bzip2 -dc | tar -xf -
    fi
    cd "$DIR"

    if [ -f "$HOME/user-config.jam" ] ; then
        mv "$HOME/user-config.jam" "$TMPD/"
    fi
    cp tools/build/example/user-config.jam "$HOME"

    TOOL="$([ "$IS_GCC" = "True" ] && echo "gcc" || echo "clang")"
    TOOLSET="${TOOL}-${TOOLCHAIN_VERSION}"
    
    cat >> $HOME/user-config.jam <<EOF
using python : $PYTHON_VERSION : /usr/bin/python3 : /usr/include/python$PYTHON_VERSION : /usr/lib ;

using $TOOL : $TOOLCHAIN_VERSION : $CXX : <cxxflags>"$CXXFLAGS" <linkflags>"$LDFLAGS" ;
EOF

    LIBRARIES="$(with_libraries | tr '\n' ' ')"
    
    ./bootstrap.sh --prefix=$PREFIX
    ./b2 --clean
    ./b2 -j $(nproc) toolset="$TOOLSET" cxxstd=${CXXSTD:3} $LIBRARIES
    ./b2 install toolset="$TOOLSET" cxxstd=${CXXSTD:3} $LIBRARIES
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "UseToolchain" "$@"

# ----------------------------------------------------------------------- action

FILE="$PREFIX/lib/cmake/Boost-1.80.0/BoostConfig.cmake"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -f "$FILE" ] ; then
    ensure_directory "$ARCH_DIR"
    build $VERSION
else
    echo "Skipping installation, cmake file found: '$FILE'"
fi

