#!/bin/bash

cd $HOME/TMP
[ -d cryptopp ] && rm -rf cryptopp
git clone --branch CRYPTOPP_7_0_0 https://github.com/weidai11/cryptopp.git

cd cryptopp

export PREFIX=/opt/WASM
export CXX="em++"
export CXXFLAGS="-std=c++17 -stdlib=libc++ -DNDEBUG -O3 -fPIC -pipe -Wall"

make -f GNUmakefile static

mkdir -p $PREFIX/include/cryptopp
mkdir -p $PREFIX/lib

cp libcryptopp.a $PREFIX/lib/
cp *.h $PREFIX/include/cryptopp/

chmod 644 $PREFIX/lib/libcryptopp.a
chmod 644 $PREFIX/include/cryptopp/*.h

echo "Installed to $PREFIX"

