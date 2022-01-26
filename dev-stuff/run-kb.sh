#!/bin/bash


export KESTREL_GIT_DIR=$HOME/Development/scorpius/project/cple/sg_cple1
#export KESTREL_GIT_DIR="$HOME/Development/SWG_NGP_kestrel"

kb stop
kb exec echo kb container is running
docker cp "$HOME/.ssh" "kestrel_build:/home/BRCMLTD/$USER"
docker cp "$HOME/.docker" "kestrel_build:/home/BRCMLTD/$USER"
docker cp "$HOME/.bashrc" "kestrel_build:/home/BRCMLTD/$USER"
# docker inspect kestrel_build | grep WorkingDir
kb shell

