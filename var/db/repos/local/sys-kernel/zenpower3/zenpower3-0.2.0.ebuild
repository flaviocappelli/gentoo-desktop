# Copyright 2020-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit dist-kernel-utils linux-mod

DESCRIPTION="Linux kernel driver for reading sensors of AMD Zen family CPUs"
HOMEPAGE="https://github.com/Ta180m/zenpower3"
SRC_URI="https://github.com/Ta180m/zenpower3/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND=""

PATCHES=(
	"${FILESDIR}/${P}-add-lucienne-support.patch"
	"${FILESDIR}/${P}-no-implicit-fallthrough.patch"
	"${FILESDIR}/${P}-use-symlink-to-detect-kernel-version.patch"
)

# See the drivers's makefile and the following page:
# https://devmanual.gentoo.org/eclass-reference/linux-mod.eclass/index.html
BUILD_TARGETS="modules"
MODULE_NAMES="zenpower(misc:${S})"

pkg_pretend() {
	if has_version virtual/dist-kernel && ! use dist-kernel; then
		ewarn "You have virtual/dist-kernel installed, but"
		ewarn "USE=\"dist-kernel\" is not enabled for ${CATEGORY}/${PN}"
		ewarn "It's recommended to globally enable dist-kernel USE flag"
		ewarn "to auto-trigger initrd rebuilds with kernel updates"
	fi
}

pkg_setup() {
	kernel_is -ge 5 4 || die "Linux 5.4 or newer required"

	# See 'make menuconfig' (module K10TEMP) and the following page:
	# https://devmanual.gentoo.org/eclass-reference/linux-info.eclass/index.html
	CONFIG_CHECK="HWMON PCI AMD_NB ~!SENSORS_K10TEMP"

	# To use this driver, the K10TEMP module must be blacklisted.
	ERROR_SENSORS_K10TEMP="SENSORS_K10TEMP: If you insist on building this, you must blacklist it!"

	linux-mod_pkg_setup
}

src_compile() {
	export KV_FULL
	linux-mod_src_compile
}

src_install() {
	linux-mod_src_install
	dodoc README.md
}

pkg_postinst() {
	linux-mod_pkg_postinst
}
