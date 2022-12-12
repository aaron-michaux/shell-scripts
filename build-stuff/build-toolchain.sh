#!/bin/bash

set -e

source "$(cd "$(dirname "$0")" ; pwd)/env.sh"

show_help()
{
    cat <<EOF

   Usage: $(basename $0) OPTION* <tool>

   Option:

      --cleanup           Remove temporary files after building
      --no-cleanup        Do not remove temporary files after building

   Tool:

      gcc-x.y.z
      llvm-x.y.z

   Examples:

      # Install gcc version 12.2.0 to $TOOLCHAINS_DIR
      > $(basename $0) gcc-12.2.0

      # Install clang version 15.0.6 to $TOOLCHAINS_DIR
      > $(basename $0) clang-15.0.6

   Repos:

      https://github.com/gcc-mirror/gcc
      https://github.com/llvm/llvm-project

EOF
}

# ------------------------------------------------------------------------ clang

build_llvm()
{
    local CLANG_V="$1"
    local TAG="$2"
    local LLVM_DIR="llvm"

    local SRC_D="$TMPD/$LLVM_DIR"
    local BUILD_D="$TMPD/build-llvm-${TAG}"
    local INSTALL_PREFIX="${TOOLCHAINS_DIR}/clang-${CLANG_V}"
    
    rm -rf "$BUILD_D"
    mkdir -p "$SRC_D"
    mkdir -p "$BUILD_D"

    cd "$SRC_D"

    if [ ! -d "llvm-project" ] ; then
        git clone https://github.com/llvm/llvm-project.git
    fi
    cd llvm-project
    git checkout main
    git pull origin main
    git checkout "llvmorg-${CLANG_V}"

    cd "$BUILD_D"

    # NOTE, to build lldb, may need to specify the python3
    #       variables below, and something else for CURSES
    # -DPYTHON_EXECUTABLE=/usr/bin/python3.6m \
    # -DPYTHON_LIBRARY=/usr/lib/python3.6/config-3.6m-x86_64-linux-gnu/libpython3.6m.so \
    # -DPYTHON_INCLUDE_DIR=/usr/include/python3.6m \
    # -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;libcxx;libcxxabi;libunwind;compiler-rt;lld" \

    nice $CMAKE -G "Unix Makefiles" \
         -D LLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld" \
         -D LLVM_ENABLE_RUNTIMES="compiler-rt;libc;libcxx;libcxxabi;libunwind" \
         -D CMAKE_BUILD_TYPE=Release \
         -D CMAKE_C_COMPILER=$HOST_CC \
         -D CMAKE_CXX_COMPILER=$HOST_CXX \
         -D LLVM_ENABLE_ASSERTIONS=Off \
         -D LIBCXX_ENABLE_STATIC_ABI_LIBRARY=Yes \
         -D LIBCXX_ENABLE_SHARED=YES \
         -D LIBCXX_ENABLE_STATIC=YES \
         -D LLVM_BUILD_LLVM_DYLIB=YES \
         -D CURSES_LIBRARY=/usr/lib/x86_64-linux-gnu/libncurses.so \
         -D CURSES_INCLUDE_PATH=/usr/include/ \
         -D CMAKE_INSTALL_PREFIX:PATH="$INSTALL_PREFIX" \
         $SRC_D/llvm-project/llvm

    nice make -j$(nproc) 2>$BUILD_D/stderr.text | tee $BUILD_D/stdout.text
    make install 2>>$BUILD_D/stderr.text | tee -a $BUILD_D/stdout.text
    cat $BUILD_D/stderr.text   
}

# -------------------------------------------------------------------------- gcc

build_gcc()
{
    local TAG="$1"
    local SUFFIX="$1"
    if [ "$2" != "" ] ; then SUFFIX="$2" ; fi
    
    local MAJOR_VERSION="$(echo "$SUFFIX" | sed 's,\..*$,,')"
    local SRCD="$TMPD/$SUFFIX"
    
    mkdir -p "$SRCD"
    cd "$SRCD"
    if [ ! -d "gcc" ] ;then
        git clone https://github.com/gcc-mirror/gcc.git
    fi
    
    cd gcc
    git fetch
    git checkout releases/gcc-${TAG}
    contrib/download_prerequisites

    if [ -d "$SRCD/build" ] ; then rm -rf "$SRCD/build" ; fi
    mkdir -p "$SRCD/build"
    cd "$SRCD/build"

    local PREFIX="${TOOLCHAINS_DIR}/gcc-${SUFFIX}"

    export CC=$HOST_CC
    export CXX=$HOST_CXX
    nice ../gcc/configure --prefix=${PREFIX} \
         --enable-languages=c,c++,objc,obj-c++ \
         --disable-multilib \
         --program-suffix=-${MAJOR_VERSION} \
         --enable-checking=release \
         --with-gcc-major-version-only
    $TIMECMD nice make -j$(nproc) 2>$SRCD/build/stderr.text | tee $SRCD/build/stdout.text
    make install | tee -a $SRCD/build/stdout.text

    # Install symlinks to /usr/local
    ensure_link "$PREFIX/bin/gcc-${MAJOR_VERSION}"        /usr/local/bin/gcc-${MAJOR_VERSION}
    ensure_link "$PREFIX/bin/g++-${MAJOR_VERSION}"        /usr/local/bin/g++-${MAJOR_VERSION}
    ensure_link "$PREFIX/bin/gcov-${MAJOR_VERSION}"       /usr/local/bin/gcov-${MAJOR_VERSION}
    ensure_link "$PREFIX/bin/gcov-dump-${MAJOR_VERSION}"  /usr/local/bin/gcov-dump-${MAJOR_VERSION}
    ensure_link "$PREFIX/bin/gcov-tool-${MAJOR_VERSION}"  /usr/local/bin/gcov-tool-${MAJOR_VERSION}
    ensure_link "$PREFIX/bin/gcc-ranlib-${MAJOR_VERSION}" /usr/local/bin/gcc-ranlib-${MAJOR_VERSION}
    ensure_link "$PREFIX/bin/gcc-ar-${MAJOR_VERSION}"     /usr/local/bin/gcc-ar-${MAJOR_VERSION}
    ensure_link "$PREFIX/bin/gcc-nm-${MAJOR_VERSION}"     /usr/local/bin/gcc-nm-${MAJOR_VERSION}
    ensure_link "$PREFIX/include/c++/${MAJOR_VERSION}"    /usr/local/include/c++/${MAJOR_VERSION}
    ensure_link "$PREFIX/lib64"                           /usr/local/lib/gcc/${MAJOR_VERSION}
    ensure_link "$PREFIX/lib/gcc"                         /usr/local/lib/gcc/${MAJOR_VERSION}/gcc
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "False" "$@"

[ "${ACTION:0:3}" = "gcc" ] && COMMAND="build_gcc ${ARG:4}"    || true
[ "${ACTION:0:4}" = "llvm" ] && COMMAND="build_llvm ${ARG:5}"  || true
[ "${ACTION:0:5}" = "clang" ] && COMMAND="build_llvm ${ARG:6}" || true

if [ "$COMMAND" = "" ] ; then
    echo "Must specify a build command!" 1>&2 && exit 1
fi

# ----------------------------------------------------------------------- action

if [ "$ACTION" != "" ] ; then
    ensure_directory "$TOOLCHAINS_DIR"
    install_dependences
    $COMMAND
fi

