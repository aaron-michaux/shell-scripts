#!/bin/bash

################################################################################
# Qt5, make, strip, flex, bison, libiconv, libxapian, graphviz, dia, mscgen    #
################################################################################

set -e

PPWD="$(cd "$(dirname "$0")" ; pwd)"
TMPD=$(mktemp -d /tmp/$(basename $0).XXXXX)

VERSION=1.8.17

trap cleanup EXIT
cleanup()
{
    # echo "Skipping cleanup"
    rm -rf $TMPD
}

sudo apt install -y flex bison libxapian-dev

cd $TMPD
wget https://sourceforge.net/projects/doxygen/files/rel-${VERSION}/doxygen-${VERSION}.src.tar.gz
cat doxygen-${VERSION}.src.tar.gz | gunzip -dc | tar -xvf -
mkdir build
cd build

cmake -D CMAKE_BUILD_TYPE=Release \
      -D english_only=ON \
      -D build_doc=OFF \
      -D build_wizard=ON \
      -D build_search=ON \
      -D build_xmlparser=ON \
      -D use_libclang=OFF \
      -D CMAKE_INSTALL_PREFIX:PATH=/usr/local \
      ../doxygen-${VERSION}

make -j$(expr $(nproc) \* 3 / 2)
sudo make install

exit $?
