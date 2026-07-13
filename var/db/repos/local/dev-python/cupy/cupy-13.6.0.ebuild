# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
#
# Copied from 'stuff' overlay with some modifications.
# Add ROCm-6.x support.
#
# NOTE: New cupy-14.x adds support for ROCm-7.x but drops
# support for ROCm-6.x, cuda-11 and cudnn (upstream recommends
# "cuDNN Frontend" for cuDNN functionality from Python).

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )
ROCM_VERSION=6.2.0
DISTUTILS_EXT=1
DISTUTILS_USE_PEP517=setuptools

inherit distutils-r1 prefix pypi rocm cuda

DESCRIPTION="NumPy-compatible array library accelerated by CUDA or ROCm"
HOMEPAGE="https://cupy.dev/"
SRC_URI="$(pypi_sdist_url "${PN^}" "${PV}")"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

IUSE="rocm cuda cudnn"

REQUIRED_USE="
	^^ ( cuda rocm )
	cudnn? ( cuda )
	rocm? ( ${ROCM_REQUIRED_USE} )
	"

# cupy 13.x's bundled cudnn module rejects cuDNN >=9 at build time
# ("WARNING: cuDNN <=v8970 is required", see cupy_setup_build.py).
# Pin <dev-libs/cudnn-9 so the dep is unsatisfiable when a newer
# cuDNN is on the system, instead of silently building a no-op stub.
DEPEND="
	>=dev-python/cython-3.1.0[${PYTHON_USEDEP}]
	>=dev-python/fastrlock-0.8.3[${PYTHON_USEDEP}]
	>=dev-python/numpy-1.22.0[${PYTHON_USEDEP}]
	cuda? ( dev-util/nvidia-cuda-toolkit[profiler] )
	cudnn? ( <dev-libs/cudnn-9 )
	rocm? (
		>=dev-util/hip-${ROCM_VERSION}
		>=dev-util/roctracer-${ROCM_VERSION}
		>=sci-libs/hipBLAS-${ROCM_VERSION}[${ROCM_USEDEP}]
		>=sci-libs/hipCUB-${ROCM_VERSION}[${ROCM_USEDEP}]
		>=sci-libs/hipFFT-${ROCM_VERSION}[${ROCM_USEDEP}]
		>=sci-libs/hipRAND-${ROCM_VERSION}[${ROCM_USEDEP}]
		>=sci-libs/rocThrust-${ROCM_VERSION}[${ROCM_USEDEP}]
		>=sci-libs/hipSPARSE-${ROCM_VERSION}[${ROCM_USEDEP}]
	 )"
RDEPEND="${DEPEND}"

EPYTEST_PLUGINS=()
distutils_enable_tests pytest

src_prepare ()
{
	default
	eprefixify cupy/cuda/compiler.py
	use cuda && cuda_src_prepare
}

src_compile() {
	if use rocm; then
		addpredict /dev/kfd
		addpredict /dev/dri/
		export CUPY_INSTALL_USE_HIP=1
		export ROCM_HOME="${EPREFIX}/usr"
		local AMDGPU_FLAGS=$(get_amdgpu_flags)
		export HCC_AMDGPU_TARGET=${AMDGPU_FLAGS//;/,}
	elif use cuda; then
		local target
		for target in ${NVPTX_TARGETS}; do
			CUPY_NVCC_GENERATE_CODE+="arch=${target/sm/compute},code=${target};"
		done
		export CUPY_NVCC_GENERATE_CODE
		export NVCC="nvcc ${NVCCFLAGS}"
	fi
	distutils-r1_src_compile
}
