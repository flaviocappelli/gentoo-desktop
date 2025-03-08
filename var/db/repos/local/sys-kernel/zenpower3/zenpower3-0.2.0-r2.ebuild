# Copyright 2022-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Copied from 'supertux88' overlay with some modifications.

EAPI=8

inherit linux-mod-r1

DESCRIPTION="Linux kernel driver for reading sensors of AMD Zen family CPUs"
HOMEPAGE="https://git.exozy.me/a/zenpower3"
SRC_URI="https://git.exozy.me/a/zenpower3/archive/v${PV}.tar.gz -> ${P}.tar.gz"

S="${WORKDIR}/zenpower3"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	!sys-kernel/zenpower
	!sys-kernel/zenstats
"

PATCHES=(
	"${FILESDIR}/${P}-add-lucienne-support.patch"
	"${FILESDIR}/${P}-no-implicit-fallthrough.patch"
	"${FILESDIR}/${P}-use-symlink-to-detect-kernel-version.patch"
	"${FILESDIR}/${P}-fix-build-on-kernel-6.14.patch"
)

# A kernel >= 5.4 is required; also, to use this driver, the K10TEMP
# driver must not be compiled (or built as module and blacklisted). See:
# https://devmanual.gentoo.org/eclass-reference/linux-info.eclass/index.html
# https://devmanual.gentoo.org/eclass-reference/linux-mod-r1.eclass/index.html

MODULES_KERNEL_MIN=5.4
CONFIG_CHECK="HWMON PCI AMD_NB ~!SENSORS_K10TEMP"
ERROR_SENSORS_K10TEMP="SENSORS_K10TEMP: If you insist on building this, you must blacklist it!"

pkg_pretend() {
	if has_version virtual/dist-kernel && ! use dist-kernel; then
		ewarn "You have virtual/dist-kernel installed, but"
		ewarn "USE=\"dist-kernel\" is not enabled for ${CATEGORY}/${PN}"
		ewarn "It's recommended to globally enable dist-kernel USE flag"
		ewarn "to auto-trigger initrd rebuilds with kernel updates"
	fi
}

src_prepare() {
	# Set kernel build dir
	sed -i "s@^KERNEL_BUILD.*@KERNEL_BUILD := ${KV_DIR}@" "${S}/Makefile" || die "Could not fix build path"

	default
}

src_compile() {
	export KV_FULL
	local modlist=( zenpower=misc:"${S}" )

	linux-mod-r1_src_compile
}
