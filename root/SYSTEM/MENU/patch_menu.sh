#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2008-2026 Flavio Cappelli
# Version 1.3
#
# See show_usage_and_exit() below.
#
# ShellCheck (-s bash -o all): PASS (2026-11-02)


set -euo pipefail

PATCHED=()
UNPATCHED=()
SCRIPTS_OK=()
SCRIPTS_ERR=()

# shellcheck disable=SC2312 # Not interested in exit code here.
DIFFDIR="$(dirname "$(realpath -e "$0")")"/DIFFDIR


show_usage_and_exit()
{
    cat <<EOF

Usage:  ${0##*/} [-R]

        Recursively check and modify desktop entries.

        With option -R, recursively restore modified desktop entries
        to their pre-patch content (resulting desktop files are still
        simplified, there is no way to revert them to their original
        version without reinstalling the related packages).

EOF
    exit 1
}


patch_desktop_entries()
{
    local dir="${1}"
    local item label ext rettxt
    local -a patch_args

    patch_args=( '-d/' '-p0' '--batch' "${DIRECTION}" )

    # Skip unmatched globs and symbolic links.
    for item in "${dir}"/*; do
        [[ ! -e "${item}" || -L "${item}" ]] && continue

        # Recurse into directories.
        if [[ -d "${item}" ]]; then
            patch_desktop_entries "${item}"
        elif [[ -f "${item}" ]]; then
            label="${dir##*/} / ${item##*/}"
            ext="${item##*.}"

            # Run auxiliary scripts in an independent Bash process.
            if [[ "${ext}" == 'sh' ]]; then
                if (
                    cd -- "${dir}" &&
                    /bin/bash -- "./${item##*/}"
                ); then
                    SCRIPTS_OK+=("${label}")
                else
                    SCRIPTS_ERR+=("${label}")
                fi
            elif [[ "${ext}" == 'diff' ]]; then

                # First check whether the patch can be applied.
                if rettxt=$(LC_ALL=C patch "${patch_args[@]}" --dry-run < "${item}"); then

                    # Apply the patch only after a successful dry-run.
                    if patch "${patch_args[@]}" < "${item}" >/dev/null; then
                        PATCHED+=("${label}")
                    else
                        UNPATCHED+=("FAILED:    ${label}")
                    fi
                else
                    # Already applied patches are intentionally ignored.
                    if [[ "${rettxt}" == *"Reversed (or previously applied) patch detected!"* ]]; then
                        :
                    elif [[ "${rettxt}" == *"No file to patch."* ]]; then
                        UNPATCHED+=("NOT FOUND: ${label}")
                    else
                        UNPATCHED+=("FAILED:    ${label}")
                    fi
                fi
            fi
        fi
    done
    return 0
}


REVERSE=0
if (( $# == 1 )) && [[ "${1}" == '-R' ]]; then
    REVERSE=1
elif (( $# )); then
    printf '\nInvalid argument\n'
    show_usage_and_exit
fi

if (( REVERSE == 0 )); then
    printf '\nSimplify .desktop files...\n'
    /root/SYSTEM/MENU/simplify_desktopfiles.py

    DIRECTION='--forward'
    printf '\nPatching menu entries...\n'
    patch_desktop_entries "${DIFFDIR}"
else
    DIRECTION='--reverse'
    printf '\nPatching menu entries (reverse mode)...\n'
    patch_desktop_entries "${DIFFDIR}"
fi

printf '\nPatching done\n'
printf '\nPatched (all ok)\n\n'
if (( ${#PATCHED[@]} )); then
    printf '  %s\n' "${PATCHED[@]}" | sort
else
    printf '  ALL ALREADY PATCHED\n'
fi
printf '\nUnpatched (something wrong)\n\n'
if (( ${#UNPATCHED[@]} )); then
    printf '  %s\n' "${UNPATCHED[@]}" | sort
else
    printf '  NONE\n'
fi
printf '\nScripts executed\n\n'
if (( ${#SCRIPTS_OK[@]} )); then
    printf '  %s\n' "${SCRIPTS_OK[@]}" | sort
else
    printf '  NONE\n'
fi
if (( ${#SCRIPTS_ERR[@]} )); then
    printf '\nScripts failed\n\n'
    printf '  %s\n' "${SCRIPTS_ERR[@]}" | sort
fi
printf '\n'

chmod -x /usr/share/applications/*.desktop
rm -f /usr/share/applications/*.orig
exit 0
