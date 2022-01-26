#!/bin/bash

export KESTREL_GIT_DIR=$HOME/sync/SWG_NGP_kestrel
echo
echo "Using KESTREL_GIT_DIR=$KESTREL_GIT_DIR"
echo
cd "$KESTREL_GIT_DIR"

kb exec make twisted_tests
