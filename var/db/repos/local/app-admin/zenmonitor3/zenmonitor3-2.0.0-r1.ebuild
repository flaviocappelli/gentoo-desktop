# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Ebuilds on variuos overlays are broken or miss something.

EAPI=8

inherit fcaps linux-info

DESCRIPTION="Monitoring software for AMD Zen-based CPUs with Zen 3 support"
HOMEPAGE="https://git.exozy.me/a/zenmonitor3"
SRC_URI="https://git.exozy.me/a/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="cli +filecaps"

CONFIG_CHECK="~X86_MSR"

S="${WORKDIR}/zenmonitor3"

DEPEND="
	!sys-apps/zenmonitor
	|| ( sys-kernel/zenpower3 sys-kernel/zenstats )
	cli? ( sys-libs/ncurses[tinfo] )
	filecaps? ( sys-libs/libcap )
	x11-libs/gtk+:3
"
RDEPEND="${DEPEND}"

PATCHES=(
	"${FILESDIR}/${PN}-arraysize.patch"
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
