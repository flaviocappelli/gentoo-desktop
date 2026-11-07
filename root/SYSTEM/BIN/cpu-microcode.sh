#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024-2026 Flavio Cappelli
# Version 1.1
#
# Check the CPU microcode.
# Latest microcode files are available in
# https://github.com/platomav/CPUMicrocodes
#
# ShellCheck (-s bash -o all): PASS (2026-10-28)

set -euo pipefail

printf '\nCheck microcode...\n'
if [[ -x /usr/bin/spectre-meltdown-checker ]]; then
    /usr/bin/spectre-meltdown-checker --hw-only | grep microcode | grep latest
    status=$?
    if (( status )); then
        printf "Execution failed\n\n"
        exit "${status}"
    fi
else
    printf "Tool 'spectre-meltdown-checker' not installed\n\n"
    exit 1
fi
printf '\n'
exit 0
