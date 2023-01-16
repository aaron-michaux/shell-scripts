#!/bin/bash

set -e

PREFIX=/usr/local
FFMPEG_TAG="n5.1.2"
VMAF_TAG="v2.3.1"
SVTAV1_TAG="v1.3.0"
BUILD_DIR=/tmp/build-$USER/ffmpeg-build

show_help()
{
    cat <<EOF

   Usage: $(basename $0)

      Builds a recent version of the ffmpeg suite, including av1 features.
      Installs to $PREFIX

   Repos:

      https://github.com/FFmpeg/FFmpeg                  $FFMPEG_TAG
      https://github.com/Netflix/vmaf                   $VMAF_TAG
      https://gitlab.com/AOMediaCodec/SVT-AV1.git       $SVTAV1_TAG

EOF
}

install_dependencies()
{
    sudo apt-get install -qq -y libtlsh-dev libunistring-dev libaom-dev libdav1d-dev autoconf automake build-essential cmake git-core libass-dev libfreetype6-dev libgnutls28-dev libmp3lame-dev libsdl2-dev libtool libva-dev libvdpau-dev libvorbis-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev meson ninja-build pkg-config texinfo wget yasm zlib1g-dev libfdk-aac-dev libvpx-dev libx265-dev libnuma-dev libx264-dev libopus-dev
}

checkout_code()
{
    local REPO="$1"
    local TAG="$2"
    local DIR="$(basename "$REPO" .git)"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    if [ ! -d "$DIR" ] ; then
        git clone "$REPO"
    fi
    cd "$DIR"
    git fetch
    git checkout "$TAG"    
}

build_vmaf()
{
    checkout_code "https://github.com/Netflix/vmaf.git" "$VMAF_TAG"
    cd "$BUILD_DIR/vmaf/libvmaf"
    rm -rf "build"
    mkdir "build"
    cd "build"
    meson setup -Denable_tests=false -Denable_docs=false --buildtype=release \
          --default-library=static  \
          .. \
          --prefix "$PREFIX"
    ninja
    ninja install
        
}

build_svtav1()
{
    checkout_code "https://gitlab.com/AOMediaCodec/SVT-AV1.git" "$SVTAV1_TAG"
    cd "$BUILD_DIR/SVT-AV1"
    git reset --hard
    git checkout "$SVTAV1_TAG"
    cd "Build"    
    cmake .. -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
    make clean
    make -j$(nproc)
    sudo make install
}

configure_and_build()
{
    cd "$BUILD_DIR/FFmpeg"
    ./configure --cpu=native --prefix="$PREFIX" --pkg-config-flags="--static" --enable-shared \
                --extra-libs="-lm -lpthread" \
                --extra-cflags="-isystem$BUILD_DIR/FFmpeg/include" \
                --extra-ldflags="-L$BUILD_DIR/FFmpeg/lib" \
                --ld=g++ \
                --enable-gpl --enable-nonfree \
                --enable-libx264 --enable-libx265 \
                --enable-libvpx \
                --enable-libfdk-aac \
                --enable-libvmaf \
                --enable-libsvtav1 --enable-libdav1d \
                --enable-libopus \
                --enable-gnutls \
                --enable-libaom \
                --enable-libass \
                --enable-libfreetype \
                --enable-libmp3lame \
                --enable-libdav1d \
                --enable-libvorbis
    
    make clean
    make -j$(nproc)
    sudo make install
}

# ------------------------------------------------------------------------------------------ ACTION!

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

install_dependencies 
checkout_code "https://github.com/FFmpeg/FFmpeg" "$FFMPEG_TAG"
build_vmaf
build_svtav1
configure_and_build


