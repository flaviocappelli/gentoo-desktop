# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Copied from 'salfter' overlay and modified for python-3.14.

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )
DISTUTILS_USE_PEP517=setuptools

inherit distutils-r1

GIT_COMMIT=0b70c51b8a3fa6b4b2ce4f8d31435ec80d0c8a3f

DESCRIPTION="Programmer for FPGA boards using the TinyFPGA USB Bootloader"
HOMEPAGE="https://github.com/tinyfpga/TinyFPGA-Bootloader/"
SRC_URI="https://github.com/tinyfpga/TinyFPGA-Bootloader/archive/$GIT_COMMIT.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="<dev-python/intelhex-3.0[${PYTHON_USEDEP}]
         <dev-python/jsonmerge-2.0[${PYTHON_USEDEP}]
         dev-python/packaging[${PYTHON_USEDEP}]
         <dev-python/pyserial-4.0[${PYTHON_USEDEP}]
         dev-python/pyusb[${PYTHON_USEDEP}]
         dev-python/six[${PYTHON_USEDEP}]
         <dev-python/tqdm-5.0[${PYTHON_USEDEP}]"
DEPEND=""

src_unpack() {
  cd $WORKDIR
  unpack $A
  mv $WORKDIR/TinyFPGA-Bootloader-$GIT_COMMIT/programmer $WORKDIR/$P
}
