#!/bin/bash

set -e

BUILDD=$HOME/TMP/build
mkdir -p "$BUILDD"

cd "$BUILDD"
git clone https://github.com/tpruvot/ccminer.git
cd ccminer
./autogen.sh

export PATH="/usr/local/cuda/bin:$PATH"
./configure --prefix=/usr/local

sed -i 's,^nvcc_ARCH,#nvcc_ARCH,' Makefile
sed -i -E 's,^#(nvcc_ARCH.*compute_75),\1,' Makefile
sed -i -E 's,^#(nvcc_ARCH.*compute_35),\1,' Makefile

cat <<EOF
have to do this to the Makefile
nvcc_ARCH += -gencode=arch=compute_75,code=\"sm_75,compute_75\" # CUDA 10 req.
#nvcc_ARCH += -gencode=arch=compute_70,code=\"sm_70,compute_70\" # CUDA 9.1
#nvcc_ARCH += -gencode=arch=compute_61,code=\"sm_61,compute_61\" # CUDA 8
#nvcc_ARCH := -gencode=arch=compute_52,code=\"sm_52,compute_52\"
#nvcc_ARCH += -gencode=arch=compute_50,code=\"sm_50,compute_50\"
nvcc_ARCH += -gencode=arch=compute_35,code=\"sm_35,compute_35\"
#nvcc_ARCH += -gencode=arch=compute_30,code=\"sm_30,compute_30\"
EOF


make -j$(nproc)

