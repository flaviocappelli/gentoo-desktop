# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Inspired by sys-kernel/zenpower3 ebuild (in this overlay).

EAPI=8

inherit git-r3 linux-mod-r1

DESCRIPTION="Linux kernel module for Nuvoton NCT6687-R Super I/O"
HOMEPAGE="https://github.com/Fred78290/nct6687d"
EGIT_REPO_URI="https://github.com/Fred78290/nct6687d.git"

LICENSE="GPL-2"
SLOT="0"

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND=""

# A kernel >= 5.11 is required; also, to use this driver, the NCT6683
# driver must not be compiled (or built as module and blacklisted). See:
# https://devmanual.gentoo.org/eclass-reference/linux-info.eclass/index.html
# https://devmanual.gentoo.org/eclass-reference/linux-mod-r1.eclass/index.html

MODULES_KERNEL_MIN=5.11
CONFIG_CHECK="HWMON ~!SENSORS_NCT6683"
ERROR_SENSORS_NCT6683="SENSORS_NCT6683: If you insist on building this, you must blacklist it!"

pkg_pretend() {
	if has_version virtual/dist-kernel && ! use dist-kernel; then
		ewarn "You have virtual/dist-kernel installed, but"
		ewarn "USE=\"dist-kernel\" is not enabled for ${CATEGORY}/${PN}"
		ewarn "It's recommended to globally enable dist-kernel USE flag"
		ewarn "to auto-trigger initrd rebuilds with kernel updates"
	fi
}

src_prepare() {
	cp -f "${FILESDIR}/${PN}-Makefile" "${S}/Makefile" || die

	eapply_user

	default
}

src_compile() {
	export KV_FULL
	local modlist=( nct6687=misc:"${S}" )

	linux-mod-r1_src_compile
}
