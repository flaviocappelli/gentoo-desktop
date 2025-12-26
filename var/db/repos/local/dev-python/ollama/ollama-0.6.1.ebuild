# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Copied from 'HomeAssistantRepository' overlay with some modifications.
# See https://projects.gentoo.org/python/guide/distutils.html

EAPI=8

PYTHON_COMPAT=( python3_{11..13} )
DISTUTILS_USE_PEP517=hatchling

inherit distutils-r1 pypi

DESCRIPTION="The Ollama Python library provides the easiest way to integrate Ollama."
HOMEPAGE="https://ollama.ai https://github.com/ollama/ollama-python https://pypi.org/project/ollama/"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

IUSE="test"
RESTRICT="!test? ( test )"

DOCS="README.md"

RDEPEND="
	sci-ml/ollama
	>=dev-python/httpx-0.28.1[${PYTHON_USEDEP}]
	>=dev-python/pydantic-2.11.4[${PYTHON_USEDEP}]
"
BDEPEND="
	test? (
		dev-python/pytest-asyncio[${PYTHON_USEDEP}]
		dev-python/pytest-cov[${PYTHON_USEDEP}]
	)"

distutils_enable_tests pytest
