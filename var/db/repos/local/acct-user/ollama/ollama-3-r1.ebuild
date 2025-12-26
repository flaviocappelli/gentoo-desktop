# Copyright 2024-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Copied with minor modifications from 'dev1990-overlay'.

EAPI=8

inherit acct-user

DESCRIPTION="System user for ollama."
KEYWORDS="~amd64"

ACCT_USER_ID=-1
ACCT_USER_HOME=/var/lib/ollama
ACCT_USER_GROUPS=( ollama )

IUSE="cuda"

acct-user_add_deps

RDEPEND+="
	cuda? (
		acct-group/video
	)
"

pkg_setup() {
	# Not required for ROCm.
	if use cuda; then
		ACCT_USER_GROUPS+=( video )
	fi
}
