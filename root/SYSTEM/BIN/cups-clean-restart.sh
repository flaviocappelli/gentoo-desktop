#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024-2026 Flavio Cappelli
# Version 1.1
#
# Restart cups (cleaning spool and logs). For Gentoo
# and other Linux distributions with systemd (running).
#
# ShellCheck (-s bash -o all): PASS (2026-10-28)

printf '\n'
if [[ ! -d /run/systemd/system ]]; then
    printf 'SYSTEMD not running. Sorry, this script is designed\n'
    printf 'for Linux distributions based on systemd. Aborting.\n\n'
    exit 1
fi

printf 'Stopping cups service...\n'
systemctl stop cups

printf 'Cleaning cups spool...\n'
rm -f /var/spool/cups/* >/dev/null 2>&1
rm -f /var/spool/cups/tmp/* >/dev/null 2>&1

printf 'Cleaning cups cache...\n'
rm -rf /var/cache/cups/* >/dev/null 2>&1

printf 'Cleaning cups logs...\n'
rm -f /var/log/cups/* >/dev/null 2>&1

printf 'Restarting cups service...\n'
systemctl start cups

printf '\n'
exit 0
