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

      # Install cmake v3.25.1 to $TOOLS_DIR/bin
      > $(basename $0) v3.25.1

   Repos:

      https://github.com/Kitware/CMake

EOF
}

# --------------------------------------------------------------------- valgrind

build_cmake()
{
    local VERSION="$1"
    local FILE_BASE="cmake-$VERSION"
    local FILE="$FILE_BASE.tar.gz"

    cd "$TMPD"
    wget "https://github.com/Kitware/CMake/archive/refs/tags/$VERSION.tar.gz"
    cat "$VERSION.tar.gz" | gzip -dc | tar -xf -

    cd "CMake-${VERSION:1}"
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
    build_cmake $ACTION
fi

