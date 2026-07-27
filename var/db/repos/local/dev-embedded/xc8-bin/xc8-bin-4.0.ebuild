# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
#
# Install the Microchip XC8 compiler under /opt/microchip/xc8/<version>
# The XC compilers are now totally free, no more license required for PRO optimizations!
#
# NOTE: the 'avr' USE flag only exposes the 'avr-objcopy' and 'avr-objdump' executables.
#       The bundled AVR compiler remains invokable internally by 'xc8-cc' even when this
#       flag is disabled. Do not enable it if you want to install the native avr-gcc
#       toolchain (which is preferred since the XC8 bundled compiler is quite old).

EAPI=8

DESCRIPTION="Microchip MPLAB XC8 C Compiler"
HOMEPAGE="https://www.microchip.com"

LICENSE="MicroChip-XC8"
SLOT="0"
KEYWORDS="~amd64"

IUSE="avr"

RESTRICT="strip"
QA_PREBUILT="*"

MY_PV_MAJ="${PV%%.*}"
MY_PV_MIN=$(printf "%02d" "${PV#*.}")
MICROCHIP_PV="v${MY_PV_MAJ}.${MY_PV_MIN}"

SRC_URI="
    https://ww1.microchip.com/downloads/aemDocuments/documents/DEV/ProductDocuments/SoftwareTools/xc8-${MICROCHIP_PV}-full-install-linux-x64.tar.xz
"

S="${WORKDIR}/xc8-${MICROCHIP_PV}"

src_install() {
	local dest="/opt/microchip/xc8/${MICROCHIP_PV}"

	dodir "${dest}" || die
	cp -pPR "${S}/." "${ED}${dest}" || die "XC8 install failed"

	# Remove unused libtool archives shipped with the prebuilt toolchain.
	find "${ED}${dest}" -name '*.la' -delete

	# Executable 'avr-gdb-py' requires deprecated Python 2.7 and is
	# not needed by XC8. Keep the regular avr-gdb binary instead.
	rm -f "${ED}${dest}/avr/bin/avr-gdb-py" || die

	for exe in "${S}"/bin/xc8-* ; do
		[[ -f ${exe} && -x ${exe} ]] || continue
		dosym "${dest}/bin/${exe##*/}" "/usr/bin/${exe##*/}"
	done

	for exe in pic-objcopy pic-objdump ; do
		[[ -f ${S}/bin/${exe} && -x ${S}/bin/${exe} ]] || continue
		dosym "${dest}/bin/${exe}" "/usr/bin/${exe}"
	done

	if use avr ; then
		for exe in avr-objcopy avr-objdump ; do
			[[ -f ${S}/bin/${exe} && -x ${S}/bin/${exe} ]] || continue
			dosym "${dest}/bin/${exe}" "/usr/bin/${exe}"
		done
	fi
}
