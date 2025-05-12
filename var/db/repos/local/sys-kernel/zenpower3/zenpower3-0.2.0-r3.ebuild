# Copyright 2022-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Copied from 'supertux88' overlay with some modifications.
# Last update: May 12, 2025 (git.exozy.me does not exists anymore).

EAPI=8

inherit linux-mod-r1

EGIT_COMMIT="ccc7d9e2d128055387ea1ca241f562a37e5ea7e0"

DESCRIPTION="Linux kernel driver for reading sensors of AMD Zen family CPUs"
HOMEPAGE="https://github.com/detiam/zenpower3"
SRC_URI="https://github.com/detiam/${PN}/archive/${EGIT_COMMIT}.tar.gz -> ${P}.tar.gz"
# Alternative URI: https://github.com/koweda (same commit).

S="${WORKDIR}/${PN}-${EGIT_COMMIT}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"

# A kernel >= 5.4 is required; also, to use this driver, the K10TEMP
# driver must not be compiled (or built as module and blacklisted). See:
# https://devmanual.gentoo.org/eclass-reference/linux-info.eclass/index.html
# https://devmanual.gentoo.org/eclass-reference/linux-mod-r1.eclass/index.html

MODULES_KERNEL_MIN=5.4
CONFIG_CHECK="HWMON PCI AMD_NB ~!SENSORS_K10TEMP"
ERROR_SENSORS_K10TEMP="SENSORS_K10TEMP: If you insist on building this, you must blacklist it!"

RDEPEND="
	!sys-kernel/zenpower
	!sys-kernel/zenstats
"

PATCHES=(
	"${FILESDIR}/${P}-add-lucienne-support.patch"
	"${FILESDIR}/${P}-amd_pci_dev_to_node_id-kernel-6.14.patch"
)

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
