#!/bin/bash

set -euo pipefail

OPT_GLIBC_VERSION=2.34
INSTALL_ROOT=/opt/glibc/${OPT_GLIBC_VERSION}
BUILD_ROOT="$(mktemp -d /tmp/$(basename "$0").XXXXXX)"

trap cleanup EXIT
cleanup() {
    rm -rf "$BUILD_ROOT"
}

mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"

# Assume the following is installed
echo "Assuming the following packages are installed: gawk bison patchelf wget"

wget -c https://ftp.gnu.org/gnu/glibc/glibc-${OPT_GLIBC_VERSION}.tar.gz 
tar -zxf glibc-${OPT_GLIBC_VERSION}.tar.gz
mkdir glibc-${OPT_GLIBC_VERSION}/glibc-build
cd glibc-${OPT_GLIBC_VERSION}/glibc-build
../configure --prefix=${INSTALL_ROOT}
make -j                          
make install                     

cat <<EOF

Glibc installed to
patchelf --set-interpreter /opt/glibc/$OPT_GLIBC_VERSION/lib/ld-linux-x86-64.so.2 \\
         --set-rpath       /opt/glibc/$OPT_GLIBC_VERSION/lib                      \\
         /path/to/executable

EOF

