#!/bin/bash


export KESTREL_GIT_DIR=$HOME/Development/scorpius/project/cple/sg_cple1

PPWD="$(cd "$(dirname "$0")" ; pwd)"

kb stop
kb exec echo kb container is running
docker cp "$HOME/.ssh" "kestrel_build:/home/BRCMLTD/$USER"
docker cp "$HOME/.docker" "kestrel_build:/home/BRCMLTD/$USER"
docker cp "$PPWD/kb-files/.profile" "kestrel_build:/home/BRCMLTD/$USER"
# docker inspect kestrel_build | grep WorkingDir
kb shell

