#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024 Flavio Cappelli
# Version 1.0
#
# Restart cups (cleaning spool and logs). For Gentoo
# and other Linux distributions with systemd (running).

echo ""
if [ ! -d /run/systemd/system ]; then
    echo "SYSTEMD not running. Sorry, this script is designed"
    echo "for Linux distributions based on systemd. Aborting."
    echo ""
    exit 1
fi

echo "Stopping cups service..."
systemctl stop cups

echo "Cleaning cups spool..."
rm -f /var/spool/cups/* >/dev/null 2>&1
rm -f /var/spool/cups/tmp/* >/dev/null 2>&1

echo "Cleaning cups cache..."
rm -rf /var/cache/cups/* >/dev/null 2>&1

echo "Cleaning cups logs..."
rm -f /var/log/cups/* >/dev/null 2>&1

echo "Restarting cups service..."
systemctl start cups

echo ""
exit 0
