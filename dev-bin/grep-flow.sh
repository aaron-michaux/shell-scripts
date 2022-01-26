#!/bin/bash

NUM="[0-9]+"
if [ "$1" -eq "$1" 2>/dev/null ] ; then
   NUM="$1"
   shift
fi 

cat "$1" | grep -E "\[F${NUM}\]" | sed 's,^[^ ]* \([0-9:\.]*\).* \(\[F[0-9]*\]\) ,\1 \2 ,'



