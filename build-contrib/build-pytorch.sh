#!/bin/bash

# Create venv
python3 -m venv .
source "bin/activate"

git clone https://github.com/pytorch/pytorch.git
cd pytorch
git fetch
git checkout .
git checkout v2.4.0

# Dependencies
sudo apt install libmagma-dev libnvtoolsext1 nvidia-cudnn

export _GLIBCXX_USE_CXX11_ABI=1
export CMAKE_PREFIX_PATH=/opt/pytorch/v2.4.0
python3 -m pip install -r requirements.txt
python3 setup.py develop
