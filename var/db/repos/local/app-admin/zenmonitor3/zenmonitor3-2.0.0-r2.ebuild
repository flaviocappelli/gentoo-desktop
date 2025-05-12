# Copyright 2022-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Ebuilds on variuos overlays are broken or miss something.
# Last update: May 12, 2025 (git.exozy.me does not exists anymore).

EAPI=8

inherit fcaps linux-info

EGIT_COMMIT="7f652ba30efc31d7da4af426e3a112cff9bebd1f"

DESCRIPTION="Monitoring software for AMD Zen-based CPUs with Zen3 support"
HOMEPAGE="https://github.com/detiam/zenmonitor3"
SRC_URI="https://github.com/detiam/${PN}/archive/${EGIT_COMMIT}.tar.gz -> ${P}.tar.gz"
# Alternative URI: https://github.com/jpr999 (same commit).

S="${WORKDIR}/${PN}-${EGIT_COMMIT}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="cli +filecaps"

CONFIG_CHECK="X86_MSR"

DEPEND="
	!sys-apps/zenmonitor
	|| (
		sys-kernel/zenpower3
		sys-kernel/zenstats
	)
	cli? ( sys-libs/ncurses[tinfo] )
	filecaps? ( sys-libs/libcap )
	x11-libs/gtk+:3
"
RDEPEND="${DEPEND}"

PATCHES=(
	"${FILESDIR}/${PN}-makefile.patch"
)

src_compile() {
	default_src_compile
	use cli && emake build-cli

	sed -e "s|@APP_EXEC@|/usr/bin/zenmonitor|" data/zenmonitor.desktop.in > zenmonitor.desktop
}

src_install() {
	dodoc README.md
	dobin zenmonitor
	use cli && dobin zenmonitor-cli

	insinto /usr/share/applications/
	doins "${S}"/zenmonitor.desktop
}

pkg_postinst() {
	fcaps cap_sys_rawio,cap_dac_read_search+ep usr/bin/zenmonitor
	use cli && fcaps cap_sys_rawio,cap_dac_read_search+ep usr/bin/zenmonitor-cli
}
