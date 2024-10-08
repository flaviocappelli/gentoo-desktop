# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Copied from the 'salfter' overlay (with cosmetic improvements).

EAPI=8

inherit cmake

GIT_COMMIT=2dab0095e1a5691855b0955b329cb4946b6a13b8
DB_GIT_COMMIT=4dda149b9e4f1753ebc8b011ece2fe794be1281a
S=$WORKDIR/$PN-$GIT_COMMIT/libtrellis

DESCRIPTION="reverse-engineered tools for Lattice ECP5 FPGAs"
HOMEPAGE="https://prjtrellis.readthedocs.io"
SRC_URI="https://github.com/YosysHQ/$PN/archive/$GIT_COMMIT.tar.gz -> $P.tar.gz
	 https://github.com/YosysHQ/$PN-db/archive/$DB_GIT_COMMIT.tar.gz -> $PN-db-$PV.tar.gz"

LICENSE="ISC"
SLOT="0"
KEYWORDS="~amd64"

DEPEND="dev-vcs/git
	dev-libs/boost"

src_unpack() {
	unpack $P.tar.gz
	cd $WORKDIR/$P
	unpack $PN-db-$PV.tar.gz
	rmdir database
	mv $PN-db-$DB_GIT_COMMIT database
	mv database $WORKDIR/$PN-$GIT_COMMIT/
}

# see https://github.com/YosysHQ/prjtrellis/pull/95
src_configure() {
	local mycmakeargs=(
		-DCURRENT_GIT_VERSION=$GIT_COMMIT
	)
	cmake_src_configure
}
