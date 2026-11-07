#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024-2026 Flavio Cappelli
# Version 1.2
#
# Launch menuconfig of specified kernel (or current running kernel). On
# exit report the saved config changes (if any) and clean the used space.
#
# This script is useful for observing how changing a particular kernel
# setting will propagate through the global kernel configuration (e.g.
# what other subsystems are affected, what are the default settings for
# all new entries in .config, etc). It helped me to obtain my kernel
# settings (see files in /etc/kernel/config.d/).
#
# ShellCheck (-s bash -o all): PASS (2026-10-30)

GENTOO_REPO='/var/db/repos/gentoo'

set -eu

usage() {

    printf '\nUsage: %s [version]\n\n' "${0##*/}" >&2
    exit 1
}

KVER_SELECTED=""
while (( $# )); do
    case "${1}" in
        -*) printf '\nError: unknow option: %s\n' "${1}" >&2
            usage
            ;;

         *) if [[ -n "${KVER_SELECTED}" ]]; then
                printf '\nError: too many arguments\n' >&2
                usage
            fi
            if [[ ! "$1" =~ ^[0-9._pr-]+$ ]]; then
                printf '\nError: invalid argoment: %s\n' "${1}" >&2
                usage
            fi
            KVER_SELECTED="$1"
            shift
            ;;
    esac
done

if [[ -z "${KVER_SELECTED}" ]]; then
    RUNNING_KERNEL=$(uname -r)
    KVER_SELECTED="${RUNNING_KERNEL%%-*}"
fi

if [[ ! -d "${GENTOO_REPO}"/sys-kernel/gentoo-kernel ]]; then
    # shellcheck disable=SC2059  # Full path inside format string.
    printf "\nError: '${GENTOO_REPO}/sys-kernel/gentoo-kernel' not found\n\n"
    exit 1
fi

EBUILD="${GENTOO_REPO}"/sys-kernel/gentoo-kernel/gentoo-kernel-"${KVER_SELECTED}".ebuild
if [[ ! -f "${EBUILD}" ]]; then
    printf '\nError: invalid kernel version: %s\n' "${KVER_SELECTED}"
    printf '\nCurrently available: '
    for file in "${GENTOO_REPO}"/sys-kernel/gentoo-kernel/gentoo-kernel-*.ebuild; do
        K_VERSION="${file##*/gentoo-kernel-}"
        K_VERSION="${K_VERSION%.ebuild}"
        printf '%s ' "${K_VERSION}"
    done
    printf '\n\n'
    exit 1
fi

ebuild "${EBUILD}" clean
ebuild "${EBUILD}" configure

cd /var/tmp/portage/sys-kernel/gentoo-kernel-"${KVER_SELECTED}"*/work/modprep
rm -f .config.old
make menuconfig

printf '\nKernel config changes\n=====================\n'
if [[ -e .config.old ]]; then
    diff -U 0 .config.old .config
else
    printf 'No changes!\n'
fi
printf '\n'

ebuild "${EBUILD}" clean
exit 0
