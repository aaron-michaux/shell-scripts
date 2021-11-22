#!/bin/bash

PROJECTD="$HOME/TMP/google-benchmark"
rm -rf "$PROJECTD"
mkdir -p "$PROJECTD"
cd "$PROJECTD"
PREFIX=/usr/local

git clone https://github.com/google/benchmark.git
# git clone https://github.com/google/googletest.git benchmark/googletest
mkdir build && cd build
cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=RELEASE -DBENCHMARK_ENABLE_GTEST_TESTS=OFF -DCMAKE_INSTALL_PREFIX:PATH=$PREFIX ../benchmark

# cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX:PATH=$PREFIX -DCMAKE_BUILD_TYPE=Release ../benchmark

make -j`nproc`
sudo make install

