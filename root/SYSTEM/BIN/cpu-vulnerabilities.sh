#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024-2026 Flavio Cappelli
# Version 1.1
#
# List known CPU vulnerabilities and mitigations.
#
# ShellCheck (-s bash -o all): PASS (2026-10-28)

set -eu
shopt -s nullglob

if [[ -d /sys/devices/system/cpu/vulnerabilities/ ]]; then
    printf '\nVulnerability             | Status\n'
    printf -- '--------------------------+-----------------------------------------------------------------------'
    for name in /sys/devices/system/cpu/vulnerabilities/*; do
        status=$(cat "${name}" || true)
        printf '\n%-25s | %s' "${name##*/}" "${status}"
    done
    printf '\n\n'
else
    printf '\nSorry, data regarding vulnerabilities is not available\n\n'
    exit 1
fi
printf "See also the 'spectre-meltdown-checker' application.\n\n"
exit 0
