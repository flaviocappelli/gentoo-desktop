#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2008-2024 Flavio Cappelli
# Version 1.2
#
# Recursively restore modified desktop entries to their pre-patch content
# (resulting desktop files are still simplified, there is no way to revert
# them to their original version without reinstalling the related packages).


DIFFDIR=/root/SYSTEM/MENU/DIFFDIR

PATCHED=""
UNPATCHED=""
SCRIPTS=""

patch_desktop_entries()
{
    local ok
    local ext
    local txt
    local item
    local rettxt

    cd "$1"
    for item in *; do
        if [ -d "$1/$item" ]; then
            patch_desktop_entries "$1/$item"
        else
            ext=$(echo "$item" | sed "s|.*\(\.[^\.]*\)$|\1|")
            if [ "$ext" == ".sh" ]; then
                . "$1/$item"
                SCRIPTS="$SCRIPTS  $(basename $1) / $item\n"
            elif [ "$ext" == ".diff" ]; then
                ok=0
                # NOTE: patch >= 2.7 wants option "-d/" to patch absolute paths;
                # also --follow-symlinks is required to patch links (see man page)
                rettxt=$(patch -d/ -p0 --follow-symlinks --batch --reverse --dry-run < "$1/$item") && ok=1
                if [ $ok -eq 1 ]; then
                    patch -d/ -p0 --follow-symlinks --batch --reverse < "$1/$item" >/dev/null
                    PATCHED="$PATCHED  $item  ($(basename $1))\n"
                else
                    txt=$(echo $rettxt | grep "Reversed (or previously applied) patch detected!")
                    if [ -z "$txt" ]; then
                        txt=$(echo $rettxt | grep "No file to patch.")
                        if [ -n "$txt" ]; then
                            UNPATCHED="$UNPATCHED  NOT FOUND: $(basename $1) / $item\n"
                        else
                            UNPATCHED="$UNPATCHED  FAILED:    $(basename $1) / $item\n"
                        fi
                    fi
                fi
            fi
        fi
    done
}


echo -e "\nStart patching menu entries..."
patch_desktop_entries $DIFFDIR

echo -e "\nPatching done"
echo -e "\nPatched (all ok)"
echo -e "$PATCHED" | sort
echo -e "\nUnpatched (something wrong)"
echo -e "$UNPATCHED" | sort
echo -e "\nScripts executed"
echo -e "$SCRIPTS" | sort
echo -e ""
