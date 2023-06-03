#!/bin/bash

set -e

source "$(cd "$(dirname "$0")" ; pwd)/env/cross-env.sh"

show_help()
{
    cat <<EOF

   Usage: $(basename $0) OPTION* <version>

   Options:

$(show_help_snippet)

   Examples:

      # Install using 'gcc'
      > $(basename $0) --toolchain=gcc --version=master

   Repos:

      https://github.com/eyalz800/zpp_bits

EOF
}

# ------------------------------------------------------------------------ build

build()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d zpp_bits ] ; then
        git clone https://github.com/eyalz800/zpp_bits
    fi
    cd zpp_bits
    git fetch
    git checkout ${VERSION}

    cp -a zpp_bits.h $PREFIX/include/
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "UseToolchain" "asan:debug tsan:debug usan:debug" "$@"

# ----------------------------------------------------------------------- action

INC_FILE="$PREFIX/include/zpp_bits.h"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -f "$INC_FILE" ] ; then
    ensure_directory "$ARCH_DIR"
    build $VERSION
else
    echo "Skipping installation, include file found: '$INC_FILE'"
fi


 
