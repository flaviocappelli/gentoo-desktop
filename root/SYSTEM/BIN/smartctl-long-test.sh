#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024-2026 Flavio Cappelli
# Version 1.1
#
# Start SMART long test on all SATA/NVMe devices. Note that NVMe
# drives needs smartmontools >= 7.4; also self tests are optional
# as of NVMe 1.3 specifications (my Sabrent NVMe units have them).
#
# ShellCheck (-s bash -o all): PASS (2026-10-28)

set -eu

TEST=long
ENABLE_NVME=1

# Enable nullglob: unmatched glob patterns expand
# to nothing instead of remaining literal 'text*'.
shopt -s nullglob

# List of devices (use an associative array to ensure there
# are no duplicates; the order in this case is not important).
declare -A devices=()

# Add SATA/SCSI SSD/HDD.
for path in /sys/block/sd*; do
    devname=${path##*/}
    if [[ "${devname}" =~ ^(sd[a-z]+) ]]; then
        devices[/dev/"${BASH_REMATCH[1]}"]=1
    fi
done

# Add PCIe NVMe.
# Note: smartctl (at least 7.4) expects 'nvme?' not 'nvme?n?'
# (otherwise it will report an error and will break the test).
if (( ENABLE_NVME )); then
    for path in /sys/block/nvme*; do
        devname=${path##*/}
        if [[ "${devname}" =~ ^(nvme[0-9]+) ]]; then
            devices[/dev/"${BASH_REMATCH[1]}"]=1
        fi
    done
fi

# Start test on selected devices.
for dev in "${!devices[@]}"; do
    printf '\nRunning SMART %s test on %s\n' "${TEST}" "${dev}"
    smartctl -t "${TEST}" "${dev}"
    printf '\n'
done
exit 0
