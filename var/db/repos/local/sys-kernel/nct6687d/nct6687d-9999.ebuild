# Copyright 2020-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit dist-kernel-utils linux-mod

DESCRIPTION="Linux kernel driver for Nuvoton NCT6687-R Super I/O"
HOMEPAGE="https://github.com/Fred78290/nct6687d.git"

if [[ ${PV} == "9999" ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/Fred78290/nct6687d.git"
else
	SRC_URI="https://github.com/Fred78290/nct6687d/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64"
fi

LICENSE="GPL-2"
SLOT="0"
IUSE=""

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND=""

# See files/Makefile and the following page:
# https://devmanual.gentoo.org/eclass-reference/linux-mod.eclass/index.html
BUILD_TARGETS="modules"
MODULE_NAMES="nct6687(misc:${S})"

pkg_pretend() {
	if has_version virtual/dist-kernel && ! use dist-kernel; then
		ewarn "You have virtual/dist-kernel installed, but"
		ewarn "USE=\"dist-kernel\" is not enabled for ${CATEGORY}/${PN}"
		ewarn "It's recommended to globally enable dist-kernel USE flag"
		ewarn "to auto-trigger initrd rebuilds with kernel updates"
	fi
}

pkg_setup() {
	kernel_is -ge 5 11 || die "Linux 5.11 or newer required"

	# See 'make menuconfig' (module NCT6683) and the following page:
	# https://devmanual.gentoo.org/eclass-reference/linux-info.eclass/index.html
	CONFIG_CHECK="HWMON ~!SENSORS_NCT6683"

	# To use this driver, the NCT6683 module must be blacklisted.
	ERROR_SENSORS_NCT6683="SENSORS_NCT6683: If you insist on building this, you must blacklist it!"

	linux-mod_pkg_setup
}

src_prepare() {
	default_src_prepare

	# by F.C.
	# The default driver's makefile incorrectly build the module for the old kernel
	# (when the kernel is upgraded). So use my makefile instead (see files/Makefile).
	cp -f "${FILESDIR}/Makefile" "${S}/Makefile"
}

src_compile() {
	export KV_FULL
	linux-mod_src_compile
}

src_install() {
	linux-mod_src_install
	dodoc LICENSE README.md
}

pkg_postinst() {
	linux-mod_pkg_postinst
}
