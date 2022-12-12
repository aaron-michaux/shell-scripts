
# ------------------------------------------------------ Host Platform Variables
export TOOLS_DIR=/opt/tools
export TOOLCHAINS_DIR=/opt/toolchains
export ARCH_DIR=/opt/arch

# Tool (host) compilers
export HOST_CC=/usr/bin/gcc
export HOST_CXX=/usr/bin/g++
export LINKER=/usr/bin/ld

export PYTHON_VERSION="$(python3 --version | awk '{print $2}' | sed 's,.[0-9]$,,')"

export CLEANUP="True"

# These dependencies need to be made, and are then used globally
export CMAKE="$TOOLS_DIR/bin/cmake"
export LLVM_DIR="/opt/tools/toolchains/clang-15.0.6"

# --------------------------------------------------------------------- Platform
export IS_UBUNTU=$([ -x /usr/bin/lsb_release ] && lsb_release -a 2>/dev/null | grep -q Ubuntu && echo "True" || echo "False")
export IS_FEDORA=$([ -f /etc/fedora-release ] && echo "True" || echo "False")
export IS_OSX=$([ "$(uname -s)" = "Darwin" ] && echo "True" || echo "False")

ensure_link()
{
    local SOURCE="$1"
    local DEST="$2"

    if [ ! -e "$SOURCE" ] ; then echo "File/directory not found '$SOURCE'" ; exit 1 ; fi
    sudo mkdir -p "$(dirname "$DEST")"
    sudo rm -f "$DEST"
    sudo ln -s "$SOURCE" "$DEST"
}

is_group()
{
    local GROUP="$1"
    cat /etc/group | grep -qE "^${GROUP}:" && return 0 || return 1
}

ensure_directory()
{
    local D="$1"
    if [ ! -d "$D" ] ; then
        echo "Directory '$D' does not exist, creating..."
        sudo mkdir -p "$D"
    fi
    if [ ! -w "$D" ] ; then
        echo "Directory '$D' is not writable by $USER, chgrp..."
        is_group staff && sudo chgrp -R staff "$D" || true
        is_group adm   && sudo chgrp -R adm   "$D" || true
        sudo chmod 775 "$D"
    fi
    if [ ! -d "$D" ] || [ ! -w "$D" ] ; then
        echo "Failed to ensure writable directory '$D', should you run as root?"
        exit 1
    fi
}

ensure_llvm_dir()
{
    if [ ! -d "$LLVM_DIR" ] ; then
        echo "Failed to find llvm installation at '$LLVM_DIR', did you forget to build llvm?" 1>&2
        exit 1
    fi
}

install_dependences()
{
    # If compiling for a different platforms, we'd augment this files with
    # brew commands (macos), yum (fedora) etc.
    if [ "$IS_UBUNTU" = "True" ] ; then
        export DEBIAN_FRONTEND=noninteractive
        sudo apt-get install -y \
             wget subversion automake swig python2.7-dev libedit-dev libncurses5-dev  \
             python3-dev python3-pip python3-tk python3-lxml python3-six              \
             libparted-dev flex sphinx-doc guile-2.2 gperf gettext expect tcl dejagnu \
             libgmp-dev libmpfr-dev libmpc-dev

    elif [ "$IS_OSX" = "True" ] ; then
        brew install coreutils
        
    fi
}

ensure_toolchain_is_valid()
{
    local TOOLCHAIN="$1"
    local TOOLCHAIN_ROOT="$TOOLCHAINS_DIR/$TOOLCHAIN"

    if [ "$TOOLCHAIN" = "" ] ; then
        echo "Toolchain not specified" 1>&2
        exit 1
        
    elif [ ! -d "$TOOLCHAIN_ROOT" ] ; then
        echo "Toolchain not found: '$TOOLCHAIN_ROOT'" 1>&2
        exit 1
    fi
}

list_toolchains()
{
    if [ -d "$TOOLCHAINS_DIR" ] ; then
        ls "$TOOLCHAINS_DIR" | sort
    fi
}

crosstool_setup()
{
    local TOOLCHAIN="$1"

    ensure_toolchain_is_valid "$TOOLCHAIN"
    
    if [ "${TOOLCHAIN:0:3}" = "gcc" ] ; then
        export IS_GCC="True"
        export IS_CLANG="False"
        export CC_MAJOR_VERSION="$(echo ${TOOLCHAIN:4} | awk -F. '{ print $1 }')"
    else
        export IS_GCC="False"
        export IS_CLANG="True"
        export CC_MAJOR_VERSION="$(echo ${TOOLCHAIN:6} | awk -F. '{ print $1 }')"
    fi

    ARCH_ALT=""
    if [ "$IS_OSX" = "True" ] ; then
        if [ "$(uname -m)" = "arm64" ] ; then
            export ARCH="aarch64-apple-darwin$(uname -r | awk -F. '{print $1}')"
        elif [ "$(uname -m)" = "x86_64" ] ; then
            export ARCH="x86_64-apple-darwin$(uname -r | awk -F. '{print $1}')"
        else
            echo "unsupported arch $(uname -m), aborting" 1>&2 && exit 1
        fi
    else
        export ARCH="$(uname -m)-pc-linux-gnu"
        export ARCH_ALT="$(uname -m)-linux-gnu"
        
    fi
            
    export TOOLCHAIN_ROOT="$TOOLCHAINS_DIR/$TOOLCHAIN"
    export PREFIX="$ARCH_DIR/${ARCH}_${TOOLCHAIN}"
    export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

    export CXXSTD="-std=c++20"
    export CFLAGS="-fPIC -O3 -isystem$PREFIX/include"
    export CXXFLAGS="-fPIC -O3 -isystem$PREFIX/include"
    [ "$IS_CLANG" = "True" ] && LDFLAGS="-fuse-ld=$LLD" || LD_FLAGS=""
    LDFLAGS+="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"
    export LDFLAGS="$LDFLAGS"
    export LIBS="-lm -pthreads"

    if [ "$IS_GCC" = "True" ] ; then
        export TOOLCHAIN_NAME="gcc"
        export CC="$TOOLCHAIN_ROOT/bin/gcc-12"
        export CXX="$TOOLCHAIN_ROOT/bin/g++-12"
        export AR="$TOOLCHAIN_ROOT/bin/gcc-ar-12"
        export NM="$TOOLCHAIN_ROOT/bin/gcc-nm-12"
        export RANLIB="$TOOLCHAIN_ROOT/bin/gcc-ranlib-12"
        export GCOV="$TOOLCHAIN_ROOT/bin/gcov-12"

        CPP_DIR="$TOOLCHAIN_ROOT/include/c++/$CC_MAJOR_VERSION"
        CXXFLAGS+=" -isystem$CPP_DIR"
        if [ -d "$CPP_DIR/$ARCH" ] ; then
            CXXFLAGS+=" -isystem$CPP_DIR/$ARCH"
        elif [ -d "$CPP_DIR/$ARCH_ALT" ] ; then
            CXXFLAGS+=" -isystem$CPP_DIR/$ARCH_ALT"
        else
            echo "Failed to find $CPP_DIR/$ARCH directory" 1>&2 && exit 1
        fi

        CPPLIB_DIR="$TOOLCHAIN_ROOT/lib/gcc/$ARCH/$CC_MAJOR_VERSION"
        CPPLIB_DIR_ALT="$TOOLCHAIN_ROOT/lib/gcc/$ARCH_ALT/$CC_MAJOR_VERSION"
        if [ -d "$CPPLIB_DIR" ] ; then
            LDFLAGS+=" -L$CPPLIB_DIR -Wl,-rpath,$CPPLIB_DIR"
        elif [ -d "$CPPLIB_DIR_ALT" ] ; then
            LDFLAGS+=" -L$CPPLIB_DIR_ALT -Wl,-rpath,$CPPLIB_DIR_ALT"
        else
            echo "Failed to find $CPPLIB_DIR directory" 1>&2 && exit 1
        fi
        export LDFLAGS="$LDFLAGS"
        export CXXFLAGS="$CXXFLAGS"
        
    elif [ "$IS_CLANG" = "True" ] ; then
        export TOOLCHAIN_NAME="clang"
        export CC="$TOOLCHAIN_ROOT/bin/clang"
        export CXX="$TOOLCHAIN_ROOT/bin/clang++"
        export AR="$TOOLCHAIN_ROOT/bin/llvm-ar"
        export NM="$TOOLCHAIN_ROOT/bin/llvm-nm"
        export RANLIB="$TOOLCHAIN_ROOT/bin/llvm-ranlib"
        export LLD="$TOOLCHAIN_ROOT/bin/ld.lld"
        
    else
        echo "logic error" 1>&2 && exit 1
    fi

    [ ! -x "$CC" ] && echo "Failed to find CC=$CC" 1>&2 && exit 1 || true
    [ ! -x "$CXX" ] && echo "Failed to find CXX=$CXX" 1>&2 && exit 1 || true
    [ ! -x "$AR" ] && echo "Failed to find AR=$AR" 1>&2 && exit 1 || true
    [ ! -x "$NM" ] && echo "Failed to find NM=$NM" 1>&2 && exit 1 || true
    [ ! -x "$RANLIB" ] && echo "Failed to find RANLIB=$RANLIB" 1>&2 && exit 1 || true

}

print_env()
{
    cat <<EOF

    TOOLS_DIR:       $TOOLS_DIR  
    ARCH_DIR:        $ARCH

    IS_UBUNTU:       $IS_UBUNTU
    IS_FEDORA:       $IS_FEDORA
    IS_OSX:          $IS_OSX

    IS_GCC:          $IS_GCC
    IS_CLANG:        $IS_CLANG

    PREFIX:          $PREFIX
    TOOLCHAIN_ROOT:  $TOOLCHAIN_ROOT  
    PKG_CONFIG_PATH: $PKG_CONFIG_PATH

    CC:              $CC
    CXX:             $CXX
    AR:              $AR
    NM:              $NM
    RANLIB:          $RANLIB
    GCOV:            $GCOV
    LLD:             $LLD

    CXXSTD:          $CXXSTD
    CFLAGS:          $CFLAGS
    CXXFLAGS:        $CXXFLAGS

    LDFLAGS:         $LDFLAGS
    LIBS:            $LIBS

    TOOLCHAINS:      $(list_toolchains | tr '\n' ' ')

EOF
}

# ---------------------------------------------------------------------- cleanup

cleanup()
{
    [ "$CLEANUP" = "True" ] && rm -rf "$TMPD" || true
}

make_working_dir()
{
    local SCRIPT_NAME="$1"

    if [ "$CLEANUP" = "True" ] ; then
        TMPD="$(mktemp -d /tmp/$(basename "$SCRIPT_NAME" .sh).XXXXXX)"
    else
        TMPD="/tmp/${USER}-$(basename "$SCRIPT_NAME" .sh)"
    fi
    if [ "$CLEANUP" = "False" ] ; then
        mkdir -p "$TMPD"
        echo "Working directory set to: TMPD=$TMPD"
    fi

    trap cleanup EXIT
}

# ------------------------------------------------------------- parse basic args

parse_basic_args()
{
    local SCRIPT_NAME="$1"
    shift
    local REQUIRE_TOOLCHAIN="$1"
    shift
    
    if (( $# == 0 )) ; then
        show_help
        exit 0
    fi

    CLEANUP="True"
    ACTION=""
    TOOLCHAIN=""
    PRINT_ENV="False"
    ACTION=""
    while (( $# > 0 )) ; do
        ARG="$1"
        shift

        [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
        [ "$ARG" = "--cleanup" ] && export CLEANUP="True" && continue
        [ "$ARG" = "--no-cleanup" ] && export CLEANUP="False" && continue
        [ "$ARG" = "--toolchain" ] && export TOOLCHAIN="$1" && shift && continue
        [ "$ARG" = "--env" ] && PRINT_ENV="True" && continue

        if [ "$ACTION" = "" ] ; then
            export ACTION="$ARG"
        else
            export ACTION="$ACTION $ARG"
        fi
    done

    if [ "$TOOLCHAIN" = "" ] ; then
        if [ "$REQUIRE_TOOLCHAIN" = "True" ] || [ "$REQUIRE_TOOLCHAIN" = "UseToolchain" ]; then
            echo "Must specify a toolchain!" 1>&2
            exit 1
        fi
        
    else
        crosstool_setup "$TOOLCHAIN"
    fi

    if [ "$PRINT_ENV" = "True" ] ; then
        print_env
        exit 0
    fi

    make_working_dir "$SCRIPT_NAME"
}


