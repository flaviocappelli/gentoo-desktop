#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024 Flavio Cappelli
# Version 1.0
#
# List known CPU vulnerabilities and mitigations.

if [ -d /sys/devices/system/cpu/vulnerabilities/ ]; then
    printf "\nVulnerability          | Status\n"
    printf "--" '-----------------------+-----------------------------------------------------------------------'
    for i in /sys/devices/system/cpu/vulnerabilities/*; do
        printf '\n%-22s | %s' "$(basename $i)" "$(cat $i)"
    done
    printf '\n\n'
else
    printf '\nSorry, not available\n'
    exit 1
fi
printf 'See also the "spectre-meltdown-checker" application\n\n'
exit 0
