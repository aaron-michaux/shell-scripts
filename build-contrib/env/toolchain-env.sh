#!/bin/bash

set -e

# Load the defaults
source "$(dirname "$BASH_SOURCE")/platform-env.sh"

show_help()
{
    cat <<EOF

   Usage: $(basename $0) OPTIONS...

   Options:      

      -p|--print                       Print the set environment variables
      --write-make-env-inc             Write include file for make that sets the environment

      --toolchain=<gcc|clang>
      --gcc-suffix=<value>
      --gcc-installation=<directory>
      --clang-installation=<directory>
      --stdlib=<libcxx|stdcxx>
      --build-config=<debug|release|asan|usan|tsan>
      --lto=<True|False>
      --coverage=<True|False>
      --unity=<True|False>
      --build-tests=<True|False>
      --build-examples=<True|False>
      --benchmark=<True|False>

EOF
}

# -------------------------------------------------------------------------------------------- parse

(( $# == 0 )) && show_help && exit 0
for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

PRINT="False"
WRITE_MAKE_ENV_INC="False"
TARGET=""
TOOL=""
GCC_SUFFIX=""
STDLIB=""
if [ "$PLATFORM" = "macos" ] ; then
    GCC_INSTALLATION="/opt/homebrew/opt/gcc@$(major_version ${DEFAULT_GCC_VERSION})"
    CLANG_INSTALLATION="/opt/homebrew/opt/llvm@$(major_version ${DEFAULT_LLVM_VERSION})"
else
    GCC_INSTALLATION="$TOOLCHAINS_DIR/$DEFAULT_GCC_VERSION"
    CLANG_INSTALLATION="$TOOLCHAINS_DIR/$DEFAULT_LLVM_VERSION"
fi
BUILD_CONFIG="debug"
LTO="False"
COVERAGE="False"
UNITY="False"
BUILD_TESTS="False"
BUILD_EXAMPLES="False"
BENCHMARK="False"
for ARG in "$@" ; do
    LHS="$(echo "$ARG" | awk -F= '{ print $1 }')"
    RHS="$(echo "$ARG" | awk -F= '{ print $2 }')"

    [ "$ARG" = "-p" ] || [ "$ARG" = "--print" ] && PRINT="True" && continue
    [ "$ARG" = "--write-make-env-inc" ] && WRITE_MAKE_ENV_INC="True" && continue
    
    [ "$LHS" = "--target" ] && TARGET="$RHS" && continue
    [ "$LHS" = "--toolchain" ] && TOOL="$RHS" && continue
    [ "$LHS" = "--gcc-suffix" ] && GCC_SUFFIX="$RHS" && continue
    [ "$LHS" = "--gcc-installation" ] && GCC_INSTALLATION="$RHS" && continue
    [ "$LHS" = "--clang-installation" ] && CLANG_INSTALLATION="$RHS" && continue
    [ "$LHS" = "--stdlib" ] && STDLIB="$RHS" && continue
    [ "$LHS" = "--build-config" ] && BUILD_CONFIG="$RHS" && continue
    [ "$LHS" = "--lto" ] && LTO="$RHS" && continue
    [ "$LHS" = "--coverage" ] && COVERAGE="$RHS" && continue
    [ "$LHS" = "--unity" ] && UNITY="$RHS" && continue
    [ "$LHS" = "--build-tests" ] && BUILD_TESTS="$RHS" && continue
    [ "$LHS" = "--build-examples" ] && BUILD_EXAMPLES="$RHS" && continue
    [ "$LHS" = "--benchmark" ] && BENCHMARK="$RHS" && continue

    echo "Unexpected argument: '$ARG'" 1>&2 && exit 1
done

# ------------------------------------------------------------------------------------ sanity checks

HAS_ERROR="False"
test_in()
{
    SWITCH="$1"
    VALUE="$2"
    LIST="$3"
    for ARG in $LIST ; do
        [ "$VALUE" = "$ARG" ] && return 0 || true
    done
    echo "Switch ${SWITCH}=${VALUE} expected a value in [$LIST]" 1>&2
    HAS_ERROR="True"
}

test_in --toolchain $TOOL "gcc clang"
test_in --stdlib $STDLIB "libcxx stdcxx"
test_in --build-config $BUILD_CONFIG "'' debug release asan usan tsan reldbg"
test_in --lto $LTO "True False"
test_in --coverage $COVERAGE "True False"
test_in --unity $UNITY "True False"
test_in --build-tests $BUILD_TESTS "True False"
test_in --build-examples $BUILD_EXAMPLES "True False"
test_in --benchmark $BENCHMARK "True False"

if [ "$TOOL" = "gcc" ] && [ ! -d "$GCC_INSTALLATION" ] ; then
    echo "gcc specified, but failed to find --gcc-installation=$GCC_INSTALLATION"
fi
if [ "$TOOL" = "clang" ] && [ ! -d "$CLANG_INSTALLATION" ] ; then
    echo "clang specified, but failed to find --clang-installation=$CLANG_INSTALLATION"
fi

if [ "$TARGET" = "" ] && [ "$WRITE_MAKE_ENV_INC" = "True" ] ; then
    echo "Target must be set to calculate build directory!" 1>&2
    HAS_ERROR="True"
fi

[ "$HAS_ERROR" = "True" ] && exit 1 || true

# ----------------------------------------------------------------------- Base Environment Varialbes

GCC_CONFIG="$(basename "$GCC_INSTALLATION")"
CLANG_CONFIG="$(basename "$CLANG_INSTALLATION")"

if [ "$GCC_SUFFIX" = "" ] && [ -d "$GCC_INSTALLATION" ] ; then
    MAJOR_VERSION="$(find "$GCC_INSTALLATION/bin" -type f -name 'gcc*' | awk -F- '{ print $NF }' | sort | uniq | head -n 1)"
    if [ "$MAJOR_VERSION" != "" ] ; then
        GCC_SUFFIX="-$MAJOR_VERSION"
    fi
fi

# ------------------------------------------------------------------------------------ Find Binaries

if [ "$TOOL" = "gcc" ] ; then
    TOOLCHAIN_ROOT="$GCC_INSTALLATION"
    CC="$GCC_INSTALLATION/bin/gcc${GCC_SUFFIX}"
    CXX="$GCC_INSTALLATION/bin/g++${GCC_SUFFIX}"
    AR="$GCC_INSTALLATION/bin/gcc-ar${GCC_SUFFIX}"
    NM="$GCC_INSTALLATION/bin/gcc-nm${GCC_SUFFIX}"
    RANLIB="$GCC_INSTALLATION/bin/gcc-ranlib${GCC_SUFFIX}"
else
    TOOLCHAIN_ROOT="$CLANG_INSTALLATION"
    CC="$CLANG_INSTALLATION/bin/clang"
    CXX="$CLANG_INSTALLATION/bin/clang++"
    AR="$CLANG_INSTALLATION/bin/llvm-ar"
    NM="$CLANG_INSTALLATION/bin/llvm-nm"
    RANLIB="$CLANG_INSTALLATION/bin/llvm-ranlib"
fi

GCOV="$GCC_INSTALLATION/bin/gcov${GCC_SUFFIX}"
LLD="$CLANG_INSTALLATION/bin/ld.lld"
LLVM_COV="$CLANG_INSTALLATION/bin/llvm-cov"
LLVM_PROFDATA="$CLANG_INSTALLATION/bin/llvm-profdata"

[ ! -x "$CC" ] && echo "Failed to find CC=$CC" 1>&2 && exit 1 || true
[ ! -x "$CXX" ] && echo "Failed to find CXX=$CXX" 1>&2 && exit 1 || true
[ ! -x "$AR" ] && echo "Failed to find AR=$AR" 1>&2 && exit 1 || true
[ ! -x "$NM" ] && echo "Failed to find NM=$NM" 1>&2 && exit 1 || true
[ ! -x "$RANLIB" ] && echo "Failed to find RANLIB=$RANLIB" 1>&2 && exit 1 || true

if [ "$TOOL" = "gcc" ] ; then
    MAJOR_VERSION="$($CC --version | head -n 1 | awk '{ print $NF }' | awk -F. '{ print $1 }'
)"
else
    MAJOR_VERSION="$($CC --version | head -n 1 | awk '{ print $3 }' | awk -F. '{ print $1 }')"
fi


# "Unset" these variables if the files were not found
[ ! -f "$LLD" ]  && LLD=""  || true
[ ! -f "$GCOV" ] && GCOV="" || true
[ ! -f "$LLVM_COV" ] && LLVM_COV="" || true
[ ! -f "$LLVM_PROFDATA" ] && LLVM_PROFDATA="" || true

if [ "$PLATFORM" = "macos" ] ; then
    [ "$(uname -m)" = "arm64" ] && ARCH="aarch64" || ARCH="x86_64"
    DARWIN_NUM="$(uname -r | cut -d . -f 1)"
    TRIPLE_LIST="${ARCH}-apple-darwin${DARWIN_NUM} ${ARCH}-apple-darwin$(expr ${DARWIN_NUM} - 1) ${ARCH}-apple-darwin$(expr ${DARWIN_NUM} - 2)"
else
    TRIPLE_LIST="$(uname -m)-linux-gnu $(uname -m)-pc-linux-gnu $(uname -m)-unknown-linux-gnu"
fi

# Compile flags
if [ "$STDLIB" = "stdcxx" ] && [ "$GCC_INSTALLATION" = "" ] ; then
    echo "Failed to set GCC_INSTALLATION for stdcxx build" 1>&2 && exit 1
elif [ "$STDLIB" = "libcxx" ] && [ "$CLANG_INSTALLATION" = "" ] ; then
    echo "Failed to set CLANG_INSTALLATION for libcxx build" 1>&2 && exit 1
    
elif [ "$STDLIB" = "stdcxx" ] && [ "$GCC_INSTALLATION" != "" ] ; then
    # --------------------------------------------------------------------------------------- stdcxx
    # Get the major version
    DIR="$GCC_INSTALLATION/include/c++"
    NPARTS="$(echo "$DIR" | tr '/' '\n' | wc -l)"
    CC_MAJOR_VERSION="$(find "$DIR" -maxdepth 1 -type d | grep "$DIR/" | awk -F/ '{ print $NF }' | sort -g | tail -n 1)"
    
    CPP_DIR="$GCC_INSTALLATION/include/c++/$CC_MAJOR_VERSION"

    CPP_INC_TRIPLE_DIR=""
    CPP_LIB_TRIPLE_DIR=""
    for TRIPLE in $TRIPLE_LIST ; do
        if [ -d "$CPP_DIR/$TRIPLE" ] ; then
            CPP_INC_TRIPLE_DIR="$CPP_DIR/$TRIPLE"
            if [ "$PLATFORM" = "macos" ] ; then
                CPP_LIB_TRIPLE_DIR="$GCC_INSTALLATION/lib/gcc/$CC_MAJOR_VERSION"
            else
                CPP_LIB_TRIPLE_DIR="$GCC_INSTALLATION/lib/gcc/$TRIPLE/$CC_MAJOR_VERSION"
            fi
            break
        fi
    done
    if [ ! -d "$CPP_INC_TRIPLE_DIR" ] ; then
        echo "Failed to find $CPP_DIR/[$TRIPLE_LIST] directory" 1>&2 && exit 1
    fi
    if [ ! -d "$CPP_LIB_TRIPLE_DIR" ] ; then
        echo "Failed to find $GCC_INSTALLATION/lib/gcc/[$TRIPLE_LIST]/$CC_MAJOR_VERSION directory" 1>&2 && exit 1
    fi

    
    [ "$TOOL" = "gcc" ] && CXXLIB_FLAGS="" || CXXLIB_FLAGS="-nostdinc++ "
    CXXLIB_FLAGS+="-isystem$CPP_DIR -isystem$CPP_INC_TRIPLE_DIR"
    CXXLIB_LDFLAGS=""
    CXXLIB_LIBS=""
    if [ "$PLATFORM" != "macos" ] ; then
        CXXLIB_LIBS+="-L$GCC_INSTALLATION/lib64 -Wl,-rpath,$GCC_INSTALLATION/lib64"
    fi
    CXXLIB_LIBS+=" -L$CPP_LIB_TRIPLE_DIR -Wl,-rpath,$CPP_LIB_TRIPLE_DIR -lstdc++"

elif [ "$STDLIB" = "libcxx" ] && [ "$CLANG_INSTALLATION" != "" ] ; then
    # --------------------------------------------------------------------------------------- libcxx
    TRIPLE=""
    if [ "$PLATFORM" != "macos" ] ; then        
        for TEST_TRIPLE in $TRIPLE_LIST ; do
            if [ -d "$CLANG_INSTALLATION/include/$TEST_TRIPLE/c++/v1" ] ; then
                TRIPLE="$TEST_TRIPLE"
                break
            fi
        done
        if [ "$TRIPLE" = "" ] ; then
            echo "Failed to find libcxx directory $CLANG_INSTALLATION/include/[$TRIPLE_LIST]/c++/v1" 1>&2
            exit 1
        fi
    fi
    
    CPPINC_DIR="$CLANG_INSTALLATION/include"
    if [ "$PLATFORM" = "macos" ] ; then
        PLATFORM_INC_DIR="$CLANG_INSTALLATION/include/c++/v1"
        CPPLIB_DIR="$CLANG_INSTALLATION/lib"
    else
        PLATFORM_INC_DIR="$CLANG_INSTALLATION/include/$TRIPLE/c++/v1"
        CPPLIB_DIR="$CLANG_INSTALLATION/lib/$TRIPLE"
    fi
    if [ ! -d "$PLATFORM_INC_DIR" ] ; then
        echo "libcxx c++ directory not found: '$PLATFORM_INC_DIR'" 1>&2 && exit 1
    fi
    if [ ! -d "$CPPLIB_DIR" ] ; then
        echo "Failed to find clang libc++ directory: '$CPPLIB_DIR'" 1>&2 && exit 1
    fi

    CXXLIB_FLAGS="-nostdinc++ -isystem$CPPINC_DIR/c++/v1 -isystem$CPPINC_DIR -isystem$PLATFORM_INC_DIR"
    if [ "$TOOL" = "gcc" ] ; then
        CXXLIB_LDFLAGS="-nodefaultlibs"
        CXXLIB_LIBS="-L$CPPLIB_DIR -lc++ -lc++abi -Wl,-rpath,$CPPLIB_DIR -lpthread -lc -lm -lgcc_s -static-libgcc -lgcc -L/lib64 -l:ld-linux-x86-64.so.2"
    else
        CXXLIB_LDFLAGS="-nostdlib++"
        CXXLIB_LIBS="-L$CPPLIB_DIR -lc++ -lc++abi -Wl,-rpath,$CPPLIB_DIR -lpthread"
    fi    
fi

# -- The Build Directory
UNIQUE_DIR="$(basename "$TOOLCHAIN_ROOT")-${STDLIB}-${BUILD_CONFIG}"
[ "$BUILD_TESTS" = "True" ] && UNIQUE_DIR="test-${UNIQUE_DIR}"
[ "$LTO" = "True" ]         && UNIQUE_DIR="${UNIQUE_DIR}-lto"
[ "$BENCHMARK" = "True" ]   && UNIQUE_DIR="bench-${UNIQUE_DIR}"
[ "$COVERAGE" = "True" ] || [ "$COVERAGE_HTML" = "True" ] && UNIQUE_DIR="coverage-${UNIQUE_DIR}"
BUILD_DIR="/tmp/build-${USER}/${UNIQUE_DIR}/${TARGET}"

# -- Make-env.inc file
MAKE_ENV_INC_FILE=$BUILD_DIR/make-env.inc

# -------------------------------------------------------------------------------------- End Actions

print_variables()
{
    cat <<EOF
# Directories
export PLATFORM=$PLATFORM
export TRIPLE_LIST="$TRIPLE_LIST"
export TOOLCHAIN_ROOT=$TOOLCHAIN_ROOT
export GCC_INSTALLATION=$GCC_INSTALLATION
export CLANG_INSTALLATION=$CLANG_INSTALLATION
export INSTALL_PREFIX=$ARCH_DIR/$(echo "$TRIPLE_LIST" | awk '{ print $1 }')_$(basename "$TOOLCHAIN_ROOT")_$STDLIB
export UNIQUE_DIR=$UNIQUE_DIR
export BUILD_DIR=$BUILD_DIR

# Important files
export MAKE_ENV_INC_FILE=$MAKE_ENV_INC_FILE

# Compiler information
export STDLIB=$STDLIB
export TOOL=$TOOL
export TOOLCHAIN=$(basename "$TOOLCHAIN_ROOT")
export MAJOR_VERSION=$MAJOR_VERSION

# Binaries
export CC=$CC
export CXX=$CXX
export AR=$AR
export NM=$NM
export RANLIB=$RANLIB
export GCOV=$GCOV
export LLD=$LLD
export LLVM_COV=$LLVM_COV
export LLVM_PROFDATA=$LLVM_PROFDATA

# build variables
export CXXLIB_FLAGS=$CXXLIB_FLAGS
export CXXLIB_LDFLAGS=$CXXLIB_LDFLAGS
export CXXLIB_LIBS=$CXXLIB_LIBS

EOF
}

[ "$PRINT" = "True" ] && print_variables || true
if [ "$WRITE_MAKE_ENV_INC" = "True" ] ; then
    mkdir -p "$BUILD_DIR"
    print_variables | sed 's,=,:=,' | sed 's,^export ,,' > $MAKE_ENV_INC_FILE
fi

eval $(print_variables)

