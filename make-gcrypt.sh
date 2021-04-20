#!/bin/bash

set -e

cd $HOME/TMP
[ -d gcrypt ] && rm -rf gcrypt
mkdir gcrypt
cd gcrypt

wget https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.32.tar.bz2
wget https://www.gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.8.3.tar.bz2

tar -xvfz libgpg-error-1.32.tar.bz2
tar -xvfz libgcrypt-1.8.3.tar.bz2

export CC=emcc
export PREFIX=/opt/WASM

cd libgpg-error-1.32
./configure --enable-static --prefix=$PREFIX 


echo "Installed to $PREFIX"

