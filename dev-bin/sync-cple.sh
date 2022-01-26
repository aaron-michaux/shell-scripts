#!/bin/bash

# # install sg
# p4 print -q //sandbox/team_monitoring/ci/docker/sg-build/centos72/dev/resources/update | bash
# # Make sure to add to path: $HOME/.local/bin

# p4 login -s

cd $HOME/Development

p4 sync //scorpius/project/cple/sg_cple1/...
p4 sync //shared/...
p4 sync //scorpius/toolchain/...
p4 sync //scorpius/project/cple/toolchain 
