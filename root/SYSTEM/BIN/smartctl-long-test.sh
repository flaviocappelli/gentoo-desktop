#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024 Flavio Cappelli
# Version 1.0
#
# Start SMART long test on all SATA/NVMe devices. Note that NVMe
# drives needs smartmontools >= 7.4; also self tests are optional
# as of NVMe 1.3 specifications (my Sabrent NVMe units have them).

TEST=long
ENABLE_NVME=1

# SATA SSD/HDD.
for d in /sys/block/sd*; do
    DEVICE=/dev/${d##*/}
	echo -e "\nRunning SMART ${TEST} test on ${DEVICE}"
	smartctl -t ${TEST} ${DEVICE}
done

# NVMe.
# Note: smartctl (at least 7.4) expects 'nvme?' not 'nvme?n?'
# (otherwise it will report an error and break the test), so
# we must ensure that only one device per NVME is listed.
if [ $ENABLE_NVME -ne 0 ]; then
    for d in $(ls -d /sys/block/nvme* | sed 's|\(nvme[0-9][0-9]*\).*|\1|' | sort | uniq); do
        DEVICE=/dev/${d##*/}
	    echo -e "\nRunning SMART ${TEST} test on ${DEVICE}"
	    smartctl -t ${TEST} ${DEVICE}
    done
fi
echo ""
