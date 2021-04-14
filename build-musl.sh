#!/bin/bash

set -e


MUSL_VERSION=1.1.20

sudo echo "Got root permissions"

# -------------------------------------------------------------------- variables

TMPD=/home/amichaux/TMP/build
mkdir -p "$TMPD"
NP=$(expr 1 \* $(cat /proc/cpuinfo | grep processor | wc -l))

# -------------------------------------------------- ensure subversion installed

sudo apt-get install -y wget subversion

# --------------------------------------------------------------------- musl cxx

buildcxxlib() {
    CC=$1
    CFLAGS=$2
    CXX=$3
    CXXFLAGS=$4
    INSTALL=$5
    BUILD=$6
    COMPILER_RT=$7

    COMMON_FLAGS="-DLLVM_PATH=$SRC/llvm
    -DLLVM_MAIN_SRC_DIR=$SRC/llvm
    -DCMAKE_ASM_COMPILER=$CC
    -DCMAKE_C_COMPILER=$CC
    -DCMAKE_C_FLAGS=$CFLAGS \
    -DCMAKE_CXX_COMPILER=$CXX \
    -DCMAKE_CXX_FLAGS=$CXXFLAGS \
    -DCMAKE_BUILD_TYPE=Release"

    echo "make libunwind"
    mkdir -p "$BUILD/libunwind" && cd "$BUILD/libunwind"
    cmake $COMMON_FLAGS \
          -DCMAKE_INSTALL_PREFIX=$INSTALL \
          -DLIBUNWIND_USE_COMPILER_RT=$COMPILER_RT \
          -DLIBUNWIND_ENABLE_STATIC=ON \
          -DLIBUNWIND_ENABLE_SHARED=OFF \
          $SRC/llvm/projects/libunwind
    make -j `nproc` install
    cd ../..

    echo "make libcxxabi"
    mkdir -p "$BUILD/libcxxabi" && cd "$BUILD/libcxxabi"
    #     -DLIBCXXABI_ENABLE_STATIC_UNWINDER doesnt seem to be implemented
    cmake $COMMON_FLAGS \
          -DCMAKE_INSTALL_PREFIX=$INSTALL \
          -DLIBCXXABI_USE_COMPILER_RT=$COMPILER_RT \
          -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
          -DLIBCXXABI_ENABLE_STATIC=ON \
          -DLIBCXXABI_ENABLE_SHARED=OFF \
          $SRC/llvm/projects/libcxxabi
    make -j `nproc` install
    cd ../..

    echo "Combine libunwind and libcxxabi into a single static library"
    mkdir -p $INSTALL/tmp
    echo "create $INSTALL/lib/libunwindc++abi.a
addlib $INSTALL/lib/libunwind.a
addlib $INSTALL/lib/libc++abi.a
save
end" | llvm-ar -M
    rm $INSTALL/lib/libunwind.a $INSTALL/lib/libc++abi.a
    mv $INSTALL/lib/libunwindc++abi.a $INSTALL/lib/libc++abi.a
    rm -rf $INSTALL/tmp

    echo "make libcxx"
    # Setting rpath here could be useful for letting libc++ find libc
    mkdir -p "$BUILD/libcxx" && cd "$BUILD/libcxx"
    cmake $COMMON_FLAGS \
          -DCMAKE_INSTALL_PREFIX=$INSTALL \
          -DLIBCXX_USE_COMPILER_RT=$COMPILER_RT \
          -DLLVM_TARGETS_TO_BUILD="$TARGETS" \
          -DLIBCXX_ENABLE_STATIC=ON \
          -DLIBCXX_ENABLE_SHARED=ON \
          -DLIBCXX_CXX_ABI="libcxxabi" \
          -DLIBCXX_CXX_ABI_INCLUDE_PATHS=$SRC/llvm/projects/libcxxabi/include \
          -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=OFF \
          -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
          -DLIBCXX_CXX_ABI_LIBRARY_PATH=$BUILD/install/lib \
          -DCMAKE_INSTALL_RPATH="$BUILD/install/lib" \
          $SRC/llvm/projects/libcxx
    make -j `nproc` install
    cd ../..

    rm $INSTALL/lib/libc++abi.a
}

build_musl_cxx()
{
    rm -rf $TMPD/musl-cxx
    mkdir $TMPD/musl-cxx
    
    cd $TMPD/musl-cxx

    wget https://www.musl-libc.org/releases/musl-$MUSL_VERSION.tar.gz
    svn co http://llvm.org/svn/llvm-project/llvm/$CLANG_V llvm
    svn co http://llvm.org/svn/llvm-project/libunwind/$CLANG_V libunwind
    svn co http://llvm.org/svn/llvm-project/libcxxabi/$CLANG_V libcxxabi
    svn co http://llvm.org/svn/llvm-project/libcxx/$CLANG_V libcxx
    
    mkdir $TMPD/musl-cxx/libunwind/build
    mkdir $TMPD/musl-cxx/libcxxabi/build
    mkdir $TMPD/musl-cxx/libcxx/build

    export CFLAGS=-fPIC
    export CXXFLAGS=-fPIC

    # Unpack musl
    cat musl-$MUSL_VERSION.tar.gz | gunzip -cd | tar -xf -
    rm musl-$MUSL_VERSION.tar.gz

    # Build musl
    cd $TMPD/musl-cxx/musl-$MUSL_VERSION
    ./configure --prefix=/opt/arch/musl-$MUSL_VERSION
    make -j$NP
    sudo make install

    # Temporarily move libc.so out of the way
    sudo mv /opt/arch/musl-$MUSL_VERSION/lib/libc.so $TMPD/musl-cxx/musl-$MUSL_VERSION/
    
    # Note CC
    MUSL_CC=/opt/arch/musl-$MUSL_VERSION/bin/musl-gcc
    
    cd $TMPD/musl-cxx/libunwind/build
    cmake -DCMAKE_C_COMPILER=$MUSL_CC \
          -DCMAKE_CXX_COMPILER=$MUSL_CC \
          -DLIBUNWIND_ENABLE_SHARED=0 \
          -DCMAKE_BUILD_TYPE=release \
          -DLLVM_PATH="$TMPD/musl-cxx/llvm" \
          ..
    make -j$NP

    cd $TMPD/musl-cxx/libcxxabi/build
    cmake -DCMAKE_C_COMPILER=$MUSL_CC \
          -DCMAKE_CXX_COMPILER=$MUSL_CC \
          -DCMAKE_SHARED_LINKER_FLAGS="-L$TMPD/musl-cxx/libunwind/build/lib" \
          -DLIBCXXABI_USE_LLVM_UNWINDER=1 \
          -DLIBCXXABI_LIBUNWIND_PATH="$TMPD/musl-cxx/libunwind" \
          -DLIBCXXABI_LIBCXX_INCLUDES="$TMPD/musl-cxx/libcxx/include" \
          -DCMAKE_BUILD_TYPE=release \
          -DLLVM_ENABLE_ASSERTIONS=Off \
          -DLIBCXXABI_ENABLE_SHARED=NO \
          -DLLVM_PATH="$TMPD/musl-cxx/llvm" \
          ..
    make -j$NP

    # put 'linux/version.h' into the musl directory
    sudo mkdir -p /opt/arch/musl-$MUSL_VERSION/include/linux
    sudo cp /usr/include/linux/version.h /opt/arch/musl-$MUSL_VERSION/include/linux
    
    cd $TMPD/musl-cxx/libcxx/build
    cmake -DCMAKE_C_COMPILER=$MUSL_CC \
          -DCMAKE_CXX_COMPILER=$MUSL_CC \
          -DLIBCXX_HAS_MUSL_LIBC=1 \
          -DLIBCXX_HAS_GCC_S_LIB=0 \
          -DLIBCXX_CXX_ABI=libcxxabi \
          -DLIBCXX_CXX_ABI_INCLUDE_PATHS="$TMPD/musl-cxx/libcxxabi/include" \
          -DLIBCXX_CXX_ABI_LIBRARY_PATH="$TMPD/musl-cxx/libcxxabi/build/lib" \
          -DCMAKE_BUILD_TYPE=release \
          -DLLVM_ENABLE_ASSERTIONS=Off \
          -DLIBCXX_ENABLE_SHARED=YES \
          -DLIBCXX_ENABLE_STATIC=YES \
          -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=YES \
          -DLLVM_PATH="$TMPD/musl-cxx/llvm" \
          -DCMAKE_INSTALL_PREFIX:PATH=/opt/arch/musl-$MUSL_VERSION \
          ..
    make -j$NP
    sudo make install

    # Restore musl's libc.so
    sudo mv $TMPD/musl-cxx/musl-$MUSL_VERSION/libc.so /opt/arch/musl-$MUSL_VERSION/lib/
}

# ------------------------------------------------------------------------ build

build_musl_cxx


