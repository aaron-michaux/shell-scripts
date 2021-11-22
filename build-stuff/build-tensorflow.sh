#!/bin/bash

set -e

VERSION=v2.0.0
PREFIX=/opt/tensorflow/${VERSION}
NO_CLEANUP=1
BAZEL=bazel-0.26.1-linux-x86_64
[ "${VERSION:0:4}" = "v2.1" ] && BAZEL=bazel-0.29.1-linux-x86_64

if [ "$NO_CLEANUP" = "1" ] ; then
    TMPD=$HOME/TMP/build-tensorflow
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
}

sudo mkdir -p ${PREFIX}

cd $TMPD

[ ! -d "tensorflow_${VERSION}" ] \
    && git clone --branch ${VERSION} https://github.com/tensorflow/tensorflow.git \
    && mv tensorflow tensorflow_${VERSION}
cd tensorflow_${VERSION}



echo <<EOF

  You need to finish this manually. Go to `tensorflow_${VERSION}`,
  and run ./configure

EOF

exit 0

./configure

CXXFLAG="-nostdinc++ -isystem/opt/gcc/10.0/include/c++/10.0.0 -isystem/opt/gcc/10.0/include/c++/10.0.0/x86_64-pc-linux-gnu"
CXXLINK="-ldl -L/opt/gcc/10.0/lib64 -Wl,-rpath,/opt/gcc/10.0/lib64 -lstdc++"
export CC=/usr/bin/gcc-8
bazel test --verbose_failures -c opt --jobs 4 --config opt --cxxopt=-nostdinc++ --cxxopt=-isystem/opt/gcc/10.0/include/c++/10.0.0 --cxxopt=-isystem/opt/gcc/10.0/include/c++/10.0.0/x86_64-pc-linux-gnu --linkopt=-ldl --linkopt=-L/opt/gcc/10.0/lib64 --linkopt=-Wl,-rpath,/opt/gcc/10.0/lib64 --linkopt=-lstdc++ //tensorflow/tools/lib_package:libtensorflow_test

bazel build -c opt --jobs 4 --config opt --cxxopt="$CXXFLAG" --linkopt="$CXXLINK" //tensorflow/tools/lib_package:libtensorflow


cd bazel-bin/tensorflow/tools/lib_package
sudo tar -C ${PREFIX} -xzf libtensorflow.tar.gz

exit 0

bazel test --jobs 4 --config opt //tensorflow/tools/lib_package:libtensorflow_test  && bazel build --jobs 4 --config opt //tensorflow/tools/lib_package:libtensorflow
