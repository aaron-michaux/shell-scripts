#!/bin/ash

VERSION=2310.3
INSTALL_DIR=/opt/o3de/$VERSION

sudo apt install libglu1-mesa-dev libxcb-xinerama0 libxcb-xinput0 libxcb-xinput-dev libxcb-xfixes0-dev libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev libfontconfig1-dev libpcre2-16-0 zlib1g-dev mesa-common-dev libunwind-dev libzstd-dev

git clone --depth 1 --branch "$VERSION" https://github.com/o3de/o3de.git
tar -c o3de | xz -zec > "o3de.$VERSION.tar.xz"

cd o3de 
mkdir build
cd build
cmake -DLY_3RDPARTY_PATH=$INSTALL_DIR/o3de-packages -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR


cmake -B build/linux -S . -G "Ninja Multi-Config" -DLY_3RDPARTY_PATH=$INSTALL_DIR/o3de-packages -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR 
cmake --build build/linux --target Editor --config profile -j $(nproc) -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR



git clone --depth 1 --branch "$VERSION" https://github.com/o3de/o3de.git && tar -c o3de | xz -zec > "o3de.$VERSION.tar.xz"
