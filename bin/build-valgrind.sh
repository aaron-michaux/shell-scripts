#!/bin/bash

# ------------------------------------------------------------------------ build

show_help()
{
    cat <<EOF

   Usage: $(basename $0) OPTION* <tool>

   Option:

      --cleanup           Remove temporary files after building
      --no-cleanup        Do not remove temporary files after building

   Tool:

      valgrind-x.y.z

EOF
}

NO_CLEANUP=1
ACTION=""
while (( $# > 0 )) ; do
    ARG="$1"
    shift

    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
    [ "$ARG" = "--cleanup" ] && NO_CLEANUP=0
    [ "$ARG" = "--no-cleanup" ] && NO_CLEANUP=1
done

if [ "$NO_CLEANUP" = "1" ] ; then
    TMPD=/tmp/build-${USER}-valgrind
else
    TMPD=$(mktemp -d /tmp/$(basename $0).XXXXXX)
fi

if [ ! -d "$TMPD" ] ; then
    mkdir -p "$TMPD"
fi

trap cleanup EXIT
cleanup()
{
    if [ "$NO_CLEANUP" != "1" ] ; then
        rm -rf $TMPD
    fi    
}

build_valgrind()
{
    VALGRIND_VERSION="$1"
    URL="https://sourceware.org/pub/valgrind/valgrind-${VALGRIND_VERSION}.tar.bz2"
    VAL_D="$TMPD/valgrind-${VALGRIND_VERSION}"
    rm -rf "$VAL_D"
    cd "$TMPD"
    if [ ! -f "valgrind-${VALGRIND_VERSION}.tar.bz2" ] ; then
        wget "$URL"
    fi
    bzip2 -dc valgrind-${VALGRIND_VERSION}.tar.bz2 | tar -xf -
    cd "$VAL_D"
    export CC=$CC_COMPILER
    ./autogen.sh
    ./configure --prefix=/usr/local
    nice ionice -c3 make -j
    sudo make install
}

build_valgrind 3.19.0
