#!/bin/sh
#
# by F.C.

arc_summary -s arc | grep -A 6 "ARC status:"

echo -e "\nARC statistics:"
arcstat
