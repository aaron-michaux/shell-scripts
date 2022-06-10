#!/bin/bash

set -e

BOOST_VERSION=1_78_0
PREFIX=/usr/local
NO_CLEANUP=1

URL="https://boostorg.jfrog.io/artifactory/main/release/$(echo $BOOST_VERSION | sed 's,_,.,g')/source/boost_${BOOST_VERSION}.tar.bz2"

if [ "$NO_CLEANUP" = "1" ] ; then
    TMPD=$HOME/TMP/boost
    mkdir -p $TMPD
else
    TMPD=$(mktemp -d /tmp/$(basename $0).XXXXXX)
fi

trap cleanup EXIT
cleanup()
{
    if ! [ "$NO_CLEANUP" = "1" ] ; then
        rm -rf $TMPD
    fi
    rm -f $HOME/user-config.jam
}

cd $TMPD
FILE=boost_${BOOST_VERSION}.tar.bz2
! [ -f "$FILE" ] && wget "$URL"

[ -d "boost_${BOOST_VERSION}" ] && rm -rf boost_${BOOST_VERSION}

tar -xf boost_${BOOST_VERSION}.tar.bz2
cd boost_${BOOST_VERSION}
cp tools/build/example/user-config.jam $HOME

#echo "using python : 3.6 : /usr/bin/python3 : /usr/include/python3.6m : /usr/lib ;" >> $HOME/user-config.jam

#  --with-libraries=filesystem,system,python,graph
./bootstrap.sh --prefix=$PREFIX
./b2 -j $(expr $(nproc) \* 3 / 2) toolset=gcc cxxstd=2a --with-system 
sudo ./b2 install toolset=gcc cxxstd=2a

