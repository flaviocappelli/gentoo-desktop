#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024 Flavio Cappelli
# Version 1.0
#
# Check the CPU microcode.
# Latest microcode files are available in
# https://github.com/platomav/CPUMicrocodes

echo -e "\nCheck microcode..."
if [ -x /usr/bin/spectre-meltdown-checker ]; then
    /usr/bin/spectre-meltdown-checker --hw-only | grep microcode | grep latest
else
    echo "Tool 'spectre-meltdown-checker' not installed"
fi
echo ""
