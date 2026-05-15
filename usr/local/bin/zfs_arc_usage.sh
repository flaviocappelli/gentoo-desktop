#!/bin/sh
#
# by F.C.

if command -v zarcsummary &> /dev/null; then
    # OpenZFS >= 2.4, see
    # https://github.com/openzfs/zfs/releases/tag/zfs-2.4.0
    zarcsummary -s arc | grep -A 6 "ARC status:"
    echo -e "\nARC statistics:"
    zarcstat
elif command -v arc_summary &> /dev/null; then
    # OpenZFS < 2.4
    arc_summary -s arc | grep -A 6 "ARC status:"
    echo -e "\nARC statistics:"
    arcstat
else
    echo "Sorry, ZFS tools not installed"
    exit 1
fi
exit 0
