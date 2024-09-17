# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Copied from the 'salfter' overlay (with cosmetic improvements).

EAPI=8

PYTHON_COMPAT=( python3_{8..12} pypy3 )
PYPI_PN=Apycula
PYPI_NO_NORMALIZE=1

inherit distutils-r1 pypi

S=$WORKDIR/Apycula-$PV

DESCRIPTION="Documentation and tools for the Gowin FPGA bitstream format"
HOMEPAGE="https://github.com/YosysHQ/apicula"

DISTUTILS_USE_PEP517=setuptools

DEPEND="dev-python/numpy
	dev-python/pandas
	dev-python/pillow
	dev-python/crcmod
	dev-python/openpyxl"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
