# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Copied from the 'salfter' overlay with cosmetic improvements
# + patch to fix the "invalid escape sequence" error messages.

EAPI=8

GIT_COMMIT=738af822905fdcf0466e9dd784b9ae4b0b34987f
S=$WORKDIR/$PN-$GIT_COMMIT

DESCRIPTION="Reverse-engineered tools for Lattice iCE40 FPGAs"
HOMEPAGE="http://www.clifford.at/icestorm/"
SRC_URI="https://github.com/YosysHQ/$PN/archive/$GIT_COMMIT.tar.gz -> $P.tar.gz"

LICENSE="ISC"
SLOT="0"
KEYWORDS="~amd64"

DEPEND="dev-embedded/libftdi
	dev-vcs/git
	dev-vcs/mercurial
	media-gfx/graphviz
	media-gfx/xdot
	dev-qt/qtcore:5
	dev-libs/boost"

PATCHES=(
	"${FILESDIR}"/fix-invalid-escape-sequence.patch
)

src_install() {
	DESTDIR="$D" PREFIX=/usr emake install
}
