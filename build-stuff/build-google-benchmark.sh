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

      # Install google benchmark
      > $(basename $0) v1.7.1

   Repos:

      https://github.com/google/benchmark

EOF
}

# --------------------------------------------------------------------- valgrind

build_google_benchmark()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d benchmark ] ; then
        git clone https://github.com/google/benchmark.git
    fi
    cd benchmark
    git fetch
    git checkout ${VERSION}    
    rm -rf build
    mkdir build
    cd build

    $CMAKE -D BENCHMARK_DOWNLOAD_DEPENDENCIES=On  \
           -D CMAKE_BUILD_TYPE=Release            \
           -D CMAKE_INSTALL_PREFIX:PATH=$PREFIX   \
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
    build_google_benchmark $ACTION
fi

