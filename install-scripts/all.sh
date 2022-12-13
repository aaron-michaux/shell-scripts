#!/bin/bash

set -e

show_help()
{
    cat <<EOF

   Usage: $(basename $0) [--cleanup|--no-cleanup|--force]*

EOF
}

# ------------------------------------------------------------------------ parse

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

OPTIONS=""
for ARG in "$@" ; do
    [ "$ARG" = "--cleanup" ] && OPTIONS="$ARG $OPTIONS" && continue
    [ "$ARG" = "--no-cleanup" ] && OPTIONS="$ARG $OPTIONS" && continue
    [ "$ARG" = "--force" ] && OPTIONS="$ARG $OPTIONS" && continue
    echo "Unexpected argument '$ARG', aborting" 1>&2 && exit 1
done

# ----------------------------------------------------------------------- action

WORKING_DIR="$(cd "$(dirname "$0")" ; pwd)"
cd "$WORKING_DIR"
source "./env.sh"

# sudo stuff
ensure_directory "$TOOLS_DIR"
ensure_directory "$TOOLCHAINS_DIR"
ensure_directory "$ARCH_DIR"

# make tools
./build-cmake.sh     $OPTIONS  --version=v3.25.1
./build-doxygen.sh   $OPTIONS  --version=1.9.5
./build-valgrind.sh  $OPTIONS  --version=3.20.0

# make toolchains
for TOOLCHAIN in "$DEFAULT_LLVM_VERSION" "$DEFAULT_GCC_VERSION" ; do
    ./build-toolchain.sh  $OPTIONS  "$TOOLCHAIN"
done

# install libraries
for STDLIB in "--libcxx" "--stdcxx" ; do
    for TOOLCHAIN in "gcc" "llvm" ; do
        if [ "$TOOLCHAIN" = "gcc" ] && [ "$STDLIB" = "--libcxx" ] ; then
            echo "skipping google-benchmark for gcc+libcxx, this combination does not build"
        else
            ./build-google-benchmark.sh  $OPTIONS  --toolchain=$TOOLCHAIN  $STDLIB  --version=v1.7.1
        fi
        ./build-google-test.sh       $OPTIONS  --toolchain=$TOOLCHAIN  $STDLIB  --version=1.12.1
    done
done


