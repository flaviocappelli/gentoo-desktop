#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024-2026 Flavio Cappelli
# Version 1.1
#
# Launch menuconfig of specified kernel (or current running kernel). On
# exit report the saved config changes (if any) and clean the used space.
#
# This script is useful for observing how changing a particular kernel
# setting will propagate through the global kernel configuration (e.g.
# what other subsystems are affected, what are the default settings for
# all new entries in .config, etc). It helped me to obtain my kernel
# settings (see files in /etc/kernel/config.d/).

set -e

# ------------------------------------------------------------------------------

usage() {

    printf '\nUsage: %s [version]\n\n' "${0##*/}" >&2
    exit 1
}

KVER_SELECTED=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -*) printf "\nError: unknow option: $1\n" >&2
            usage
            ;;

         *) if [[ -n "${KVER_SELECTED}" ]]; then
                printf "\nError: too many arguments\n" >&2
                usage
            fi

            if [[ ! "$1" =~ ^[0-9._pr-]+$ ]]; then
                printf "\nError: invalid argoment: $1\n" >&2
                usage
            fi

            KVER_SELECTED="$1"
            shift
            ;;
    esac
done

if [[ -z "${KVER_SELECTED}" ]]; then
    KVER_SELECTED=$(uname -r | sed 's|-.*||')
fi

EBUILD="/var/db/repos/gentoo/sys-kernel/gentoo-kernel/gentoo-kernel-${KVER_SELECTED}.ebuild"
if [[ ! -f "$EBUILD" ]]; then
    printf "\nError: invalid kernel version: ${KVER_SELECTED}\n"
    printf "\nCurrently available: %s\n\n" "$(
        printf '%s\n' /var/db/repos/gentoo/sys-kernel/gentoo-kernel/gentoo-kernel-*.ebuild |
        sed 's|.*/gentoo-kernel-||; s|\.ebuild$||' |
        tr '\n' ' '
    )"
    exit 1
fi

ebuild "${EBUILD}" clean
ebuild "${EBUILD}" configure

cd /var/tmp/portage/sys-kernel/gentoo-kernel-${KVER_SELECTED}*/work/modprep

rm -f .config.old
make menuconfig

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
