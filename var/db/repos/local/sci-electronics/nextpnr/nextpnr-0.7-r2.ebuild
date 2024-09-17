# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Copied from the 'salfter' overlay (with cosmetic improvements).
# Add patch for 'boost-1.85' (not yet in 'salfner' overlay).
# Add 'himbaechel' target (not yet in 'salfner' overlay).

EAPI=8

inherit cmake

S=$WORKDIR/nextpnr-$P

DESCRIPTION="portable FPGA place and route tool"
HOMEPAGE="https://github.com/YosysHQ/nextpnr"
SRC_URI="https://github.com/YosysHQ/nextpnr/archive/$P.tar.gz"

LICENSE="ISC"
SLOT="0"
KEYWORDS="~amd64"
IUSE="ice40 ecp5 machxo2 nexus gowin himbaechel gui"

DEPEND="ice40? ( sci-electronics/icestorm )
	ecp5? ( sci-electronics/prjtrellis )
	machxo2? ( sci-electronics/prjtrellis )
	nexus? ( sci-electronics/prjoxide )
	gowin? ( sci-electronics/apicula )
	himbaechel? ( sci-electronics/apicula )
	>=sci-electronics/yosys-0.8
	gui? ( dev-qt/qtcore:5
               virtual/opengl )
	dev-libs/boost
	dev-cpp/eigen"

PATCHES=(
	"${FILESDIR}/${P}-boost-1.85-patch"
)

src_unpack() {
	unpack $P.tar.gz
	rmdir $S/3rdparty/fpga-interchange-schema # $S/3rdparty/abseil-cpp
}

src_configure() {
	local mycmakeargs=(
		-DARCH=generic$(usex ice40 ";ice40" "")$(usex ecp5 ";ecp5" "")$(usex machxo2 ";machxo2" "")$(usex nexus ";nexus" "")$(usex gowin ";gowin" "")$(usex himbaechel ";himbaechel" "")
		$(usex ice40 "-DICESTORM_INSTALL_PREFIX=/usr" "")
		$(usex ecp5 "-DTRELLIS_INSTALL_PREFIX=/usr" "")
		$(usex machxo2 "-DTRELLIS_INSTALL_PREFIX=/usr" "")
		$(usex nexus "-DOXIDE_INSTALL_PREFIX=/usr" "")
		$(usex himbaechel "-DHIMBAECHEL_GOWIN_DEVICES=all" "")
		$(usex gui -DBUILD_GUI=ON "")
	)
	cmake_src_configure
}
