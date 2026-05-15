# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Add support for LLVM 21
# Fix standalone-install-location.patch
# See also https://bugs.gentoo.org/965513

EAPI=8

LLVM_COMPAT=( {19..21} )
PYTHON_COMPAT=( python3_{11..14} )
inherit cmake llvm-r1 python-any-r1

MY_P="${PN}-v${PV}"

DESCRIPTION="Compiler plugin which allows clang to understand Qt semantics"
HOMEPAGE="https://apps.kde.org/clazy"
SRC_URI="mirror://kde/stable/${PN}/${PV}/src/${MY_P}.tar.xz -> ${P}.tar.xz"

LICENSE="LGPL-2+"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~x86"
IUSE="test"
RESTRICT="!test? ( test )"

RDEPEND="
	$(llvm_gen_dep 'llvm-core/clang:${LLVM_SLOT}')
	$(llvm_gen_dep 'llvm-core/llvm:${LLVM_SLOT}')
"
DEPEND="${RDEPEND}"
BDEPEND="
	test? (
		${PYTHON_DEPS}
		dev-qt/qtbase:6[network,xml]
		dev-qt/qtmultimedia:6
		dev-qt/qtnetworkauth:6
		dev-qt/qtscxml:6[qml]
		dev-qt/qtsvg:6
	)
"

PATCHES=(
	# downstream patches
	"${FILESDIR}"/${PN}-1.12-LIBRARY_DIRS.patch
	"${FILESDIR}"/${PN}-1.12-INCLUDE_DIRS.patch
	"${FILESDIR}"/${PN}-1.16-standalone-install-location.patch
	"${FILESDIR}"/${PN}-1.12-clazy-install-location.patch
)

S="${WORKDIR}/${MY_P}"

pkg_setup() {
	use test && python-any-r1_pkg_setup
	llvm-r1_pkg_setup
}

src_prepare() {
	cmake_src_prepare

	sed -e '/install(FILES README.md COPYING-LGPL2.txt checks.json DESTINATION/d' \
		-i CMakeLists.txt || die
}

src_configure() {
	local -x LLVM_ROOT="$(get_llvm_prefix -d)"

	export CI_JOB_NAME_SLUG="qt6"

	cmake_src_configure
}

src_test() {
	# clazy-standalone wants to be installed in the directory of the clang binary,
	# so it can find the llvm/clang via relative paths.
	# Requires the standalone-install-location.patch.
	# Setup the directories and symlink the system include dir for that.
	local -x LLVM_ROOT="$(get_llvm_prefix -d)"
	local -x CLANG_ROOT="${LLVM_ROOT//llvm/clang}"
	mkdir -p "${BUILD_DIR}${CLANG_ROOT}" || die

	ln -s "${CLANG_ROOT}/include" "${BUILD_DIR}${CLANG_ROOT}/include" || die

	# Run tests against built copy, not installed
	# bug #811723
	local -x PATH="${BUILD_DIR}/${LLVM_ROOT}/bin:${BUILD_DIR}/bin:${PATH}"
	local -x LD_LIBRARY_PATH="${BUILD_DIR}/lib"

	chmod +x "${BUILD_DIR}/bin/clazy" || die

	cmake_src_test
}

src_install() {
	docompress -x /usr/share/doc/${PF}

	cmake_src_install
}
