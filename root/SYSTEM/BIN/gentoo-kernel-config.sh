#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024 Flavio Cappelli
# Version 1.0
#
# Launch menuconfig (or xconfig) of current running kernel. On exit
# report the saved config changes (if any) and clean the used space.
#
# This script is useful for observing how changing a particular kernel
# setting will propagate through the global kernel configuration (e.g.
# what other subsystems are affected, what are the default settings for
# all new entries in .config, etc). It helped me to obtain my kernel
# settings (see files in /etc/kernel/config.d/).

set -e

USE_X=0
if [ -n "$1" ]; then
    case "$1" in
        -x) if [ -z "${DISPLAY}" ]; then
                echo -e "\nNo X server available\n" >&2
                exit 1

            fi
            if ! timeout 1s xset q &>/dev/null; then
                echo -e "\nNo X server at \$DISPLAY [$DISPLAY]\n" >&2
                exit 1
            fi
            USE_X=1
            ;;
         *) echo -e "\nUsage: $0 [-x]"
            echo -e "-x needs qt + X running or X forwarding\n"
            exit 1
            ;;
    esac
fi

if [ ! -e /usr/bin/equery ]; then
    echo -e "\nPlease install app-portage/gentoolkit\n"
    exit 1
fi

KVER=$(uname -r | sed 's|-.*||')
EBUILD=$(equery list -F '/var/db/repos/$repo/$cp/$name-$fullversion.ebuild' gentoo-kernel | grep "${KVER}")

ebuild "${EBUILD}" clean
ebuild "${EBUILD}" configure

cd /var/tmp/portage/sys-kernel/gentoo-kernel-${KVER}*/work/modprep

rm -f .config.old
if [ ${USE_X} -eq 0 ]; then
    make menuconfig
else
    make xconfig
fi

echo ""
echo "Kernel config changes"
echo "====================="
if [ -e .config.old ]; then
    diff -U 0 .config.old .config
else
    echo "No changes!"
fi
echo ""

ebuild "${EBUILD}" clean
exit 0
