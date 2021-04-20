#!/bin/dash

# ------------------------------------------------------------------------- wasm
build_wasm()
{
    [ -d /opt/WASM/trunk ] && sudo rm -rf /opt/WASM/trunk
    sudo mkdir -p /opt/WASM/trunk
    sudo chown -R amichaux:amichaux /opt/WASM/trunk

    cd /opt/WASM/trunk    
    git clone https://github.com/juj/emsdk.git
    cd emsdk
    ./emsdk install  --build=Release sdk-incoming-64bit binaryen-master-64bit
    ./emsdk activate --build=Release sdk-incoming-64bit binaryen-master-64bit
    # source ./emsdk_env.sh --build=Release
}

build_wasm
