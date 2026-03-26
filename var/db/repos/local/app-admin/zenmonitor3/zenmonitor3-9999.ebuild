# Copyright 2022-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Ebuilds on variuos overlays are broken or miss something.

EAPI=8

inherit git-r3 fcaps linux-info

DESCRIPTION="Monitoring software for AMD Zen-based CPUs (Zen3, Zen4, Zen5)"
HOMEPAGE="https://github.com/detiam/zenmonitor3"
EGIT_REPO_URI="https://github.com/detiam/zenmonitor3.git"

LICENSE="MIT"
SLOT="0"
IUSE="cli +filecaps"

CONFIG_CHECK="X86_MSR"

DEPEND="
	!sys-apps/zenmonitor
	|| (
		sys-kernel/zenpower5
		sys-kernel/zenpower3
		sys-kernel/zenstats
	)
	cli? ( sys-libs/ncurses[tinfo] )
	filecaps? ( sys-libs/libcap )
	x11-libs/gtk+:3
"
RDEPEND="${DEPEND}"

PATCHES=(
	"${FILESDIR}/${P}-makefile.patch"
	"${FILESDIR}/${P}-zen5-support.patch"
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
