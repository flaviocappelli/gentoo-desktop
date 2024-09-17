#!/bin/sh
#
# by F.C.

echo $(arc_summary | grep "ARC size (current):" | sed -e 's/ +/ /g' -e 's/%/%,/')
