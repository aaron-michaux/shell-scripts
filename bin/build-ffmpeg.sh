#!/bin/bash

set -e

sudo apt-get install -y libtlsh-dev libunistring-dev libaom-dev libdav1d-dev autoconf automake build-essential cmake git-core libass-dev libfreetype6-dev libgnutls28-dev libmp3lame-dev libsdl2-dev libtool libva-dev libvdpau-dev libvorbis-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev meson ninja-build pkg-config texinfo wget yasm zlib1g-dev

cd "$(cd "$(dirname "$0")" ; pwd)"

BUILD_DIR=/tmp/build-$USER/ffmpeg
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [ ! -f ffmpeg-snapshot.tar.bz2 ] ; then
    wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
fi
if [ ! -d ffmpeg ] ; then
    tar xjvf ffmpeg-snapshot.tar.bz2
fi

cd ffmpeg
./configure --cpu=native --prefix=/usr/local --pkg-config-flags="--static" --enable-shared --extra-libs="-lm -lpthread" --ld=g++ \
            --enable-gpl \
            --enable-gnutls \
            --enable-libaom \
            --enable-libass \
            --enable-libfdk-aac \
            --enable-libfreetype \
            --enable-libmp3lame \
            --enable-libopus \
            --enable-libdav1d \
            --enable-libvorbis \
            --enable-libvpx \
            --enable-libx264 \
            --enable-libx265 \
            --enable-nonfree 

make -j$(nproc)
sudo make install
