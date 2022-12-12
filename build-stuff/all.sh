#!/bin/bash

set -e

WORKING_DIR="$(cd "$(dirname "$0")" ; pwd)"
cd "$WORKING_DIR"
source "./env.sh"

CLEANOPT="--no-cleanup"

ensure_directory "$TOOLS_DIR"
ensure_directory "$TOOLCHAINS_DIR"
ensure_directory "$ARCH_DIR"

LLVM_VERSION="clang-15.0.6"
GCC_VERSION="gcc-12.2.0"
TOOLCHAINS="$LLVM_VERSION $GCC_VERSION"
STDLIBS="--libcxx --stdcxx"

./build-cmake.sh     $CLEANOPT  v3.25.1
./build-doxygen.sh   $CLEANOPT  1.9.5
./build-valgrind.sh  $CLEANOPT  3.20.0

for TOOLCHAIN in $TOOLCHAINS ; do
    ./build-toolchain.sh  $CLEANOPT  "$TOOLCHAIN"
done

for STDLIB in $STDLIBS ; do
    for TOOLCHAIN in $TOOLCHAINS ; do
        TOOLCHAIN_ARG=""
        if [ "$TOOLCHAIN" = "$LLVM_VERSION" ] ; then
            TOOLCHAIN_ARG="--toolchain $LLVM_VERSION --alt-toolchain $GCC_VERSION"
        elif [ "$TOOLCHAIN" = "$GCC_VERSION" ] ; then
            TOOLCHAIN_ARG="--toolchain $GCC_VERSION --alt-toolchain $LLVM_VERSION"
        else
            echo "logic error with toolchain args: '$TOOLCHAIN'" 1>&2 && exit 1
        fi
        
        ./build-google-benchmark.sh  $CLEANOPT  $TOOLCHAIN_ARG  $STDLIB  v1.7.1
        ./build-google-test.sh       $CLEANOPT  $TOOLCHAIN_ARG  $STDLIB  1.12.1
    done
done

