#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024 Flavio Cappelli
# Version 1.0
#
# Simplify installation / configuration of the grub
# bootloader and the rebuild of initramfs (if needed).
# THIS SCRIPT IS ONLY FOR UEFI SYSTEMS AND HAS BEEN
# TESTED ONLY ON LINUX MINT 21, MX LINUX AND GENTOO.


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
GRUBGEN_UNREQUIRED=("05_debian_theme" "10_linux_zfs" "20_linux_xen" "30_os-prober" "30_uefi-firmware" "35_fwupd")


# This does not need an explanation!
show_usage_and_exit() {
    echo ""
    echo "Usage:  $(basename $0) options"
    echo ""
    echo "Options:"
    echo "  -h  display this usage summary"
    if [ ${ENABLE_INITRAMFS_OPT} -ne 0 ]; then
        echo "  -i  rebuild initramfs using dracut"
    fi
    echo "  -r  install/reinstall grub (UEFI systems)"
    echo "  -u  update grub configuration"
    echo ""
    if [ ${ENABLE_INITRAMFS_OPT} -ne 0 ]; then
        echo "Initramfs must be rebuilt when:"
        echo " * the kernel is upgraded or rebuilt"
        echo " * some external modules are upgraded or rebuilt"
        echo " * files embedded in initramsf by dracut are updated"
        echo " * the zfs configuration is modified (when zfs is used)"
        echo ""
    fi
    exit 1
}

# Regenerate initramfs (see above
# when initramfs must be rebuilt).
gen_initramfs()
{
    echo "INITRAMFS GENERATION"
    dracut --force
    echo ""
}

# Install or reinstall grub to a device (EFI systems
# only). If /boot/efi is not already mounted then it
# is mounted automatically (and unmounted when done).
grub_efi_install()
{
    local efimount=0

    echo "GRUB EFI INSTALL"
    if [ -e /sys/firmware/efi ]; then
        if ! mountpoint -q /boot/efi; then
            mount /boot/efi
            efimount=1
        fi
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=$DISTRO --recheck

        # See Gentoo NEWS 2024-02-01 (GRUB upgrades).
        if [ $ENABLE_GRUBINSTALL_REMOVABLE -ne 0 ]; then
            grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=$DISTRO --recheck --removable
        fi
        if [ $efimount -ne 0 ]; then
            umount /boot/efi
        fi
    else
        echo -e "\nError: this option is for UEFI systems!\n"
        exit 1
    fi
    echo ""
}

# Update GRUB configuration.
grub_config_update()
{
    echo "GRUB CONFIG UPDATE"

    # Remove old kernel.
    rm -f /boot/*.old

    # Disable unrequired grub generators.
    for gen in ${GRUBGEN_UNREQUIRED[@]}; do
        if [ -e /etc/grub.d/$gen ]; then
            chmod -x /etc/grub.d/$gen
        fi
    done

    # Enable (+x) or disable (-x) memtest86+.
    if [ -e /etc/grub.d/*_memtest86+ ]; then
        if [ $ENABLE_MEMTEST86 -ne 0 ]; then
            chmod +x /etc/grub.d/*_memtest86+
        else
            chmod -x /etc/grub.d/*_memtest86+
        fi
    fi

    # Patch menu entries for unrestricted access.
    sed -i 's|^CLASS="--class gnu-linux --class gnu --class os"|CLASS="--class gnu-linux --class gnu --class os --unrestricted"|' /etc/grub.d/10_linux

    # Generate grub configuration file.
    grub-mkconfig -o /boot/grub/grub.cfg "$@"

    # Silent grub for Linux boot.
    sed -i "/echo[[:space:]]*'Loading Linux/d" /boot/grub/grub.cfg
    sed -i "/echo[[:space:]]*'Loading initial/d" /boot/grub/grub.cfg
    echo ""
}

# Perform some safety checks.
if [ ! -x /usr/bin/mountpoint ]; then
    echo -e "\nError: \"/usr/bin/mountpoint\" not found!\n"
    exit 1
fi
if [ ! -x /usr/sbin/grub-install ]; then
    echo -e "\nError: \"/usr/sbin/grub-install\" not found!\n"
    exit 1
fi
if [ ! -x /usr/sbin/grub-mkconfig ]; then
    echo -e "\nError: \"/usr/sbin/grub-mkconfig\" not found!\n"
    exit 1
fi
if [ ${ENABLE_INITRAMFS_OPT} -ne 0 ]; then
    if [ ! -x /usr/bin/dracut ]; then
        echo -e "\nError: \"/usr/bin/dracut\" not found!\n"
        exit 1
    fi
fi

# Process options.
GEN_INITRAMFS=0
GRUB_EFI_INSTALL=0
GRUB_CONFIG_UPDATE=0
case ${ENABLE_INITRAMFS_OPT} in
    0) OPTIONS=":hru"  ;;
    *) OPTIONS=":hiru" ;;
esac
while getopts "${OPTIONS}" opt; do
    case ${opt} in
        h) show_usage_and_exit
           ;;
        i) GEN_INITRAMFS=1
           ;;
        r) GRUB_EFI_INSTALL=1
           ;;
        u) GRUB_CONFIG_UPDATE=1
           ;;
        ?) echo -e "\nError: invalid option -${OPTARG}  (use -h for help)\n"
           exit 1
           ;;
    esac
done

# Check if at least one option is enabled.
if [ ${GEN_INITRAMFS} -eq 0 -a ${GRUB_EFI_INSTALL} -eq 0 -a ${GRUB_CONFIG_UPDATE} -eq 0 ]; then
    echo -e "\nError: at least one option must be specified  (use -h for help)\n"
    exit 1
fi

# Stop on errors.
set -e

# Perform requested actions.
echo ""
[[ ${GEN_INITRAMFS} -ne 0 ]] && gen_initramfs
[[ ${GRUB_EFI_INSTALL} -ne 0 ]] && grub_efi_install
[[ ${GRUB_CONFIG_UPDATE} -ne 0 ]] && grub_config_update
exit 0
