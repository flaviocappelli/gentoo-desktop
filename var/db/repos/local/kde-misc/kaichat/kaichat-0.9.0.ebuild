# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

ECM_HANDBOOK="optional"
ECM_TEST="true"
KFMIN=6.26.0
QTMIN=6.10.0
KTEXTADDONS_MIN=2.2.0
inherit ecm kde.org optfeature

DESCRIPTION="Chat interface for AI language models (local with Ollama, or online services)"
HOMEPAGE="https://apps.kde.org/kaichat/ https://invent.kde.org/utilities/kaichat"

# For the time being, KAIChat is NOT part of KDE Gear (it has its own release cycle).
SRC_URI="https://download.kde.org/stable/${PN}/${P}.tar.xz"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="~amd64"

IUSE="share telemetry"

DEPEND="
	>=dev-libs/ktextaddons-${KTEXTADDONS_MIN}:6=[speech]
	>=dev-qt/qtbase-${QTMIN}:6[dbus,gui,network,sql,sqlite,widgets]
	>=kde-frameworks/kcmutils-${KFMIN}:6
	>=kde-frameworks/kconfig-${KFMIN}:6
	>=kde-frameworks/kcoreaddons-${KFMIN}:6
	>=kde-frameworks/kcrash-${KFMIN}:6
	>=kde-frameworks/kdbusaddons-${KFMIN}:6
	>=kde-frameworks/kglobalaccel-${KFMIN}:6
	>=kde-frameworks/ki18n-${KFMIN}:6
	>=kde-frameworks/kiconthemes-${KFMIN}:6
	>=kde-frameworks/kio-${KFMIN}:6
	>=kde-frameworks/knotifications-${KFMIN}:6
	>=kde-frameworks/knotifyconfig-${KFMIN}:6
	>=kde-frameworks/kstatusnotifieritem-${KFMIN}:6
	>=kde-frameworks/kwidgetsaddons-${KFMIN}:6
	>=kde-frameworks/kwindowsystem-${KFMIN}:6
	>=kde-frameworks/kxmlgui-${KFMIN}:6
	>=kde-frameworks/sonnet-${KFMIN}:6
	>=kde-frameworks/syntax-highlighting-${KFMIN}:6
	share? ( >=kde-frameworks/purpose-${KFMIN}:6 )
	telemetry? ( >=kde-frameworks/kuserfeedback-${KFMIN}:6 )
"
RDEPEND="${DEPEND}"
BDEPEND=">=x11-misc/shared-mime-info-1.10"

src_configure() {
	local mycmakeargs=(
		-DUSE_DBUS=ON
		-DUSE_MCP_SERVER_SUPPORT=ON
		-DUSE_MOLD_LINKER=OFF
		# KF6TextSpeechToText (optional, ktextaddons >= 2.2): not
		# handled in Gentoo, disabled to avoid automagical dependencies.
		-DCMAKE_DISABLE_FIND_PACKAGE_KF6TextSpeechToText=ON
		$(cmake_use_find_package share KF6Purpose)
		$(cmake_use_find_package telemetry KF6UserFeedback)
	)
	ecm_src_configure
}

pkg_postinst() {
	optfeature "running local language models" sci-ml/ollama
	ecm_pkg_postinst
}
