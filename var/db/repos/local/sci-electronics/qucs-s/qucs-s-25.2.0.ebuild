# Copyright 1999-2025 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Merged ebuild from 'phackerlay' and 'guru' overlays.
# See also "https://github.com/ra3xdh/qucs_s" (dependencies).
# NOTE: Qt5 support has been dropped since v25.1.0.

EAPI=8

inherit cmake xdg

DESCRIPTION="Quite universal circuit simulator with SPICE"
HOMEPAGE="https://ra3xdh.github.io/"
SRC_URI="https://github.com/ra3xdh/qucs_s/releases/download/${PV}/${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+ngspice"

DEPEND="
	dev-qt/qtbase:6[gui,opengl,widgets]
	dev-qt/qtcharts:6
	dev-qt/qttools:6
	dev-qt/qtsvg:6
	"
RDEPEND="
	${DEPEND}
	ngspice? ( sci-electronics/ngspice )
	"
BDEPEND="
	app-text/dos2unix
	dev-util/gperf
	dev-vcs/git
	sys-devel/bison
	sys-devel/flex
	"

pkg_postinst() {
	xdg_icon_cache_update
}

pkg_postrm() {
	xdg_icon_cache_update
}
