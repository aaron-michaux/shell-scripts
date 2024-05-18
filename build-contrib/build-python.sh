#!/bin/bash

set -euo pipefail

VERSION=3.10.13
PREFIX=/usr/local
SUFFIX="$(echo $VERSION | awk -F. '{ print $1"."$2 }')"


TMPD="$(mktemp -d /tmp/$(basename $0).XXXXXX)"
trap cleanup EXIT
cleanup()
{
    sudo rm -rf "$TMPD"
}

# Install dependencies
sudo apt-get update
# sudo apt-get upgrade
sudo apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev liblzma-dev tk-dev


cd "$TMPD"
wget https://www.python.org/ftp/python/${VERSION}/Python-${VERSION}.tgz
tar xzf Python-${VERSION}.tgz
cd Python-${VERSION}

./configure --prefix=/usr/local/ --enable-optimizations --with-lto --with-computed-gotos --with-system-ffi --enable-shared
make -j 
# sudo LD_LIBRARY_PATH=$(pwd) ./python -m test -j "$(nproc)"
sudo make altinstall

sudo ldconfig

sudo ${PREFIX}/bin/python${SUFFIX} -m pip install --upgrade pip setuptools wheel

cd "${PREFIX}/bin"
sudo rm -f python3 python pip3 pip pydoc idle python-config

sudo ln -s python${SUFFIX}        python3
sudo ln -s python3                python
sudo ln -s pip${SUFFIX}           pip3
sudo ln -s pip3                   pip
sudo ln -s pydoc${SUFFIX}         pydoc
sudo ln -s idle${SUFFIX}          idle
sudo ln -s python${SUFFIX}-config      python-config
