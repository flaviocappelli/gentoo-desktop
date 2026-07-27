# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
#
# Install the Microchip XC32 compiler under /opt/microchip/xc32/<version>
# The XC compilers are now totally free, no more license required for PRO optimizations!

EAPI=8

DESCRIPTION="Microchip XC32 C/C++ Compiler"
HOMEPAGE="https://www.microchip.com"

LICENSE="MicroChip-XC32"
SLOT="0"
KEYWORDS="~amd64"

RESTRICT="strip"
QA_PREBUILT="*"

MY_PV_MAJ="${PV%%.*}"
MY_PV_MIN=$(printf "%02d" "${PV#*.}")
MICROCHIP_PV="v${MY_PV_MAJ}.${MY_PV_MIN}"

SRC_URI="
	https://ww1.microchip.com/downloads/aemDocuments/documents/DEV/ProductDocuments/SoftwareTools/xc32-${MICROCHIP_PV}-full-install-linux-x64.tar.xz
"

S="${WORKDIR}/xc32-${MICROCHIP_PV}"

src_install() {
	local dest="/opt/microchip/xc32/${MICROCHIP_PV}"

	dodir "${dest}" || die
	cp -pPR "${S}/." "${ED}${dest}" || die "XC32 install failed"

	for exe in "${S}"/bin/xc32-* ; do
		[[ -f ${exe} && -x ${exe} ]] || continue
		dosym "${dest}/bin/${exe##*/}" "/usr/bin/${exe##*/}"
	done
}
