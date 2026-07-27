# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
#
# Install the Microchip XC-DSC compiler under /opt/microchip/xc-dsc/<version>
# The XC compilers are now totally free, no more license required for PRO optimizations!

EAPI=8

# Required for make_wrapper, see below.
inherit wrapper

DESCRIPTION="Microchip XC-DSC C/C++ Compiler"
HOMEPAGE="https://www.microchip.com"

LICENSE="MicroChip-XC-DSC"
SLOT="0"
KEYWORDS="~amd64"

RESTRICT="strip"
QA_PREBUILT="*"

MY_PV_MAJ="${PV%%.*}"
MY_PV_MIN=$(printf "%02d" "${PV#*.}")
MICROCHIP_PV="v${MY_PV_MAJ}.${MY_PV_MIN}"

SRC_URI="
	https://ww1.microchip.com/downloads/aemDocuments/documents/DEV/ProductDocuments/SoftwareTools/xc-dsc-${MICROCHIP_PV}-full-install-linux64.tar.xz
"

# Required to fix xc-dsc-clangd, see below.
BDEPEND="
    dev-util/patchelf
"

S="${WORKDIR}/xc-dsc-${MICROCHIP_PV}"

src_install() {
	local dest="/opt/microchip/xc-dsc/${MICROCHIP_PV}"

	dodir "${dest}" || die
	cp -pPR "${S}/." "${ED}${dest}" || die "XC-DSC install failed"

	# Fix warning "scanelf: rpath_security_checks(): Security problem NULL DT_RUNPATH in
	# /var/tmp/portage/dev-embedded/xc-dsc-bin-*/image/opt/microchip/xc-dsc/*/bin/xc-dsc-clangd"
	local clangd="${ED}${dest}/bin/xc-dsc-clangd"
	if [[ -x ${clangd} ]]; then
		local rpath=$(patchelf --print-rpath "${clangd}") || die

		if [[ ${rpath} == *: ]]; then
			einfo "Removing trailing ':' from RUNPATH of xc-dsc-clangd"
			patchelf --set-rpath "${rpath%:}" "${clangd}" || die
		fi
    fi

	# XC-DSC drivers locate their ELF backend tools (bin/elf-*) relative to
	# the driver path, therefore they cannot be symlinked into /usr/bin. We
	# must use wrappers instead, that preserve the original installation path.
	for exe in "${S}"/bin/xc-dsc-* ; do
		[[ -f ${exe} && -x ${exe} ]] || continue
		make_wrapper "${exe##*/}" "${dest}/bin/${exe##*/}" ""
	done
}
