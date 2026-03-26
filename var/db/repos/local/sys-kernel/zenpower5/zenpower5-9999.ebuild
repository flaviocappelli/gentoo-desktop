# Copyright 2022-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Inspired by sys-kernel/nct6687d ebuild (in this overlay).

EAPI=8

inherit git-r3 linux-mod-r1

DESCRIPTION="Linux kernel driver for AMD Zen CPU monitoring (Zen 1-5)"
HOMEPAGE="https://github.com/mattkeenan/zenpower5"
EGIT_REPO_URI="https://github.com/mattkeenan/zenpower5.git"

LICENSE="GPL-2"
SLOT="0"

# A kernel >= 5.4 is required; also, to use this driver, the K10TEMP
# driver must not be compiled (or built as module and blacklisted). See:
# https://devmanual.gentoo.org/eclass-reference/linux-info.eclass/index.html
# https://devmanual.gentoo.org/eclass-reference/linux-mod-r1.eclass/index.html

MODULES_KERNEL_MIN=5.4
CONFIG_CHECK="HWMON PCI AMD_NB ~!SENSORS_K10TEMP"
ERROR_SENSORS_K10TEMP="SENSORS_K10TEMP: If you insist on building this, you must blacklist it!"

RDEPEND="
	!sys-kernel/zenstats
	!sys-kernel/zenpower
	!sys-kernel/zenpower3
"
pkg_pretend() {
	if has_version virtual/dist-kernel && ! use dist-kernel; then
		ewarn "You have virtual/dist-kernel installed, but"
		ewarn "USE=\"dist-kernel\" is not enabled for ${CATEGORY}/${PN}"
		ewarn "It's recommended to globally enable dist-kernel USE flag"
		ewarn "to auto-trigger initrd rebuilds with kernel updates"
	fi
}

src_compile() {
    # Override variable TARGET in makefile (patch not longer needed).
    local modargs=( TARGET="${KV_FULL}" )

    # Specify module destdir:sourcedir.
    local modlist=( zenpower=misc:"${S}" )

    linux-mod-r1_src_compile
}
