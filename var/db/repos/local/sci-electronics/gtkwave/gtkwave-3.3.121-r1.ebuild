# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Copied from the 'gentoo' repo, revert to gtk2: currently
# the gtk3 version has issues under PLASMA6 with wayland
# (see https://github.com/gtkwave/gtkwave/issues/335).

EAPI=8

inherit toolchain-funcs xdg

DESCRIPTION="A wave viewer for LXT, LXT2, VZT, GHW and standard Verilog VCD/EVCD files"
HOMEPAGE="http://gtkwave.sourceforge.net/"
SRC_URI="https://downloads.sourceforge.net/${PN}/${P}.tar.gz"

LICENSE="GPL-2 MIT"
SLOT="0"
KEYWORDS="~amd64 ~ppc ~x86 ~amd64-linux ~x86-linux"
IUSE="doc examples fasttree fatlines judy lzma packed tcl"

RDEPEND="
	dev-libs/glib:2
	sys-libs/zlib
	x11-libs/pango
	x11-libs/gtk+:2
	judy? ( dev-libs/judy )
	tcl? ( dev-lang/tcl:0 dev-lang/tk:0 )
	lzma? ( app-arch/xz-utils )"
DEPEND="${RDEPEND}"
BDEPEND="
	dev-util/gperf
	virtual/pkgconfig"

src_prepare() {
	default

	# do not install doc and examples by default
	sed -i -e 's/doc examples//' Makefile.in || die
}

src_configure() {
	econf \
		--disable-mime-update \
		--enable-largefile \
		$(use_enable packed struct-pack) \
		$(use_enable fatlines) \
		$(use_enable tcl) \
		$(use_enable lzma xz) \
		$(use_enable fasttree) \
		$(use_enable judy)
}

src_compile() {
	emake AR="$(tc-getAR)"
}

src_install() {
	default

	use doc && dodoc doc/${PN}.odt
	if use examples; then
		rm examples/Makefile* || die
		dodoc -r examples
		docompress -x /usr/share/doc/${PF}/examples
	fi
}
