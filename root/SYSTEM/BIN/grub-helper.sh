#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024-2026 Flavio Cappelli
# Version 1.1
#
# Simplify installation / configuration of the grub
# bootloader and the rebuild of initramfs (if needed).
# THIS SCRIPT IS ONLY FOR UEFI SYSTEMS AND HAS BEEN
# TESTED ONLY ON LINUX MINT 21, MX LINUX AND GENTOO.
#
# ShellCheck (-s bash -o all): PASS (2026-10-28)


# Exit immediately on command failures
# (unless explicitly handled).
set -eu

# Enable nullglob: unmatched glob patterns expand
# to nothing instead of remaining literal 'text*'.
shopt -s nullglob

# Distribution name: this determines the directory created
# under /boot/efi/EFI. NOTE: Linux Mint wants 'ubuntu' here.
DISTRO=Gentoo

# Enable Memtest86+ (if installed) in the grub boot menu.
ENABLE_MEMTEST86=1

# Enable (and show) the '-i' option to rebuild initramfs.
ENABLE_INITRAMFS_OPT=1

# Enable 'grub-install --removable' (in addition to 'grub-install').
ENABLE_GRUBINSTALL_REMOVABLE=1

# List of grub generators that will be disabled (see /etc/grub.d/*).
GRUBGEN_UNREQUIRED=('05_debian_theme' '10_linux_zfs' '20_linux_xen' '30_os-prober' '30_uefi-firmware' '35_fwupd')


# This does not need an explanation!
show_usage_and_exit()
{
    printf '\nUsage:  %s options\n\n' "${0##*/}"
    printf 'Options:\n'
    printf '  -h  display this usage summary\n'
    if (( ENABLE_INITRAMFS_OPT )); then
        printf '  -i  rebuild initramfs using dracut\n'
    fi
    printf '  -r  install/reinstall grub (UEFI systems)\n'
    printf "  -u  update grub configuration\n\n"
    if (( ENABLE_INITRAMFS_OPT )); then
        printf 'Initramfs must be rebuilt when:\n'
        printf ' * the kernel is upgraded or rebuilt\n'
        printf ' * some external modules are upgraded or rebuilt\n'
        printf ' * files embedded in initramsf by dracut are updated\n'
        printf ' * the zfs configuration is modified (when zfs is used)\n\n'
    fi
    exit 0
}

# Herror handler.
fatal_error()
{
    printf "\nError: %s\n\n" "${1}" >&2
    exit 1
}

# Regenerate initramfs (see above when initramfs must be rebuilt).
gen_initramfs()
{
    printf 'INITRAMFS GENERATION\n'
    dracut -v --force
    printf '\n'
}

# Install or reinstall grub into a device (EFI systems only). If /boot/efi is
# not already mounted then it is mounted automatically (and unmounted when done).
grub_efi_install()
{
    local efimount=0

    printf 'GRUB EFI INSTALL\n'
    if [[ -e /sys/firmware/efi ]]; then
        if ! mountpoint -q /boot/efi; then
            if ! mount /boot/efi; then
                fatal_error "Cannot mount '/boot/efi'"
            fi
            efimount=1
        fi
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="${DISTRO}" --recheck

        # See Gentoo NEWS 2024-02-01 (GRUB upgrades). NOTE: The --removable option does not need
        # the --efi-directory option (it is ignored if provided), because it install the  GRUB's PE32+
        # executable to [EFI PARTITION]\EFI\BOOT\BOOTX64.efi (see https://wiki.gentoo.org/wiki/GRUB).
        if (( ENABLE_GRUBINSTALL_REMOVABLE )); then
            grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck
        fi
        if (( efimount )); then
            umount /boot/efi
        fi
    else
        fatal_error 'This option is for UEFI systems'
    fi
    printf '\n'
}

# Update GRUB configuration.
grub_config_update()
{
    printf "GRUB CONFIG UPDATE\n"

    # Remove old kernel.
    rm -f /boot/*.old

    # Disable unrequired grub generators.
    for gen in "${GRUBGEN_UNREQUIRED[@]}"; do
        if [[ -e /etc/grub.d/"${gen}" ]]; then
            chmod -x /etc/grub.d/"${gen}"
        fi
    done

    # Enable (+x) or disable (-x) memtest86+.
    for mt in /etc/grub.d/*_memtest86+; do
        if (( ENABLE_MEMTEST86 )); then
            chmod +x "${mt}"
        else
            chmod -x "${mt}"
        fi
    done

    # Patch menu entries for unrestricted access.
    sed -i 's|^CLASS="--class gnu-linux --class gnu --class os"|CLASS="--class gnu-linux --class gnu --class os --unrestricted"|' /etc/grub.d/10_linux

    # Generate grub configuration file.
    grub-mkconfig -o /boot/grub/grub.cfg

    # Silent grub for Linux boot.
    sed -i "/echo[[:space:]]*'Loading Linux/d" /boot/grub/grub.cfg
    sed -i "/echo[[:space:]]*'Loading initial/d" /boot/grub/grub.cfg

    # Set GRUB default boot entry (first).
    printf 'Set grub default boot to first entry (0)\n'
    grub-set-default 0
    printf '\n'
}

# Perform some safety checks.
if [[ ! -x /usr/bin/mountpoint ]]; then
    fatal_error "'/usr/bin/mountpoint' not found"
fi
if [[ ! -x /usr/sbin/grub-install ]]; then
    fatal_error "'/usr/sbin/grub-install' not found"
fi
if [[ ! -x /usr/sbin/grub-mkconfig ]]; then
    fatal_error "'/usr/sbin/grub-mkconfig' not found"
fi
if (( ENABLE_INITRAMFS_OPT )); then
    if [[ ! -x /usr/bin/dracut ]]; then
        fatal_error "'/usr/bin/dracut' not found"
    fi
fi

# Process options.
GEN_INITRAMFS=0
GRUB_EFI_INSTALL=0
GRUB_CONFIG_UPDATE=0
case "${ENABLE_INITRAMFS_OPT}" in
    0) OPTIONS=':hru'  ;;
    *) OPTIONS=':hiru' ;;
esac
while getopts "${OPTIONS}" opt; do
    case "${opt}" in
        h) show_usage_and_exit
           ;;
        i) GEN_INITRAMFS=1
           ;;
        r) GRUB_EFI_INSTALL=1
           ;;
        u) GRUB_CONFIG_UPDATE=1
           ;;
        :) fatal_error "Option '-${OPTARG}' requires an argument (use -h for help)"
           ;;
        *) fatal_error "Invalid option '-${OPTARG}' (use -h for help)"
           ;;
    esac
done

# Check if at least one option is enabled.
if (( GEN_INITRAMFS == 0 && GRUB_EFI_INSTALL == 0 && GRUB_CONFIG_UPDATE == 0 )); then
    fatal_error 'At least one option must be specified (use -h for help)'
fi

# Ensure the script is run with root privileges. NOTE: the 'id' command
# is provided by 'GNU Coreutils', 'BusyBox', or other essential system
# packages, and is generally available on all major Linux distributions,
# as well as on other Unix-like systems (*BSD, macOS, Solaris, AIX, QNX).
# This is preferable to using the EUID variable (which is easily altered).
CMD_ID='/usr/bin/id'
if [[ -x ${CMD_ID} ]]; then
    if ! USERID=$(${CMD_ID} -u); then
        fatal_error "Command '${CMD_ID}' failed to run"
    fi
    (( USERID )) && fatal_error 'This script needs root privileges'
else
    fatal_error "Command '${CMD_ID}' not available"
fi

# Perform requested actions.
printf '\n'
(( GEN_INITRAMFS )) && gen_initramfs
(( GRUB_EFI_INSTALL )) && grub_efi_install
(( GRUB_CONFIG_UPDATE )) && grub_config_update
exit 0
