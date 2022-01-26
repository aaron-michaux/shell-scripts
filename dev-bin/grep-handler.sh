#!/bin/bash

cat "$1" | grep -E 'handler.cc' | sed 's,^[^ ]* \([0-9:\.]*\).*flow_event_handler.cc:[0-9]*\],\1,'



