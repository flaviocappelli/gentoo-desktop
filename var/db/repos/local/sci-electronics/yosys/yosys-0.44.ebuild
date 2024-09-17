# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Copied from the 'salfter' overlay (with cosmetic improvements).
# The build changed from 0.41 to 0.42 (old method doesn't work anymore).

EAPI=8

inherit git-r3

DESCRIPTION="Framework for Verilog RTL synthesis"
HOMEPAGE="http://www.clifford.at/yosys/"

EGIT_REPO_URI=https://github.com/YosysHQ/yosys
EGIT_COMMIT=$P

LICENSE="ISC"
SLOT="0"
KEYWORDS="~amd64"

PATCHES=( $FILESDIR/$PN-makefile.patch )

DEPEND="dev-vcs/git
	media-gfx/xdot
	dev-libs/boost
	sys-devel/clang"

src_compile()
{
  emake DESTDIR="$D" PREFIX=/usr
}

src_install()
{
  emake DESTDIR="$D" PREFIX=/usr install
}
