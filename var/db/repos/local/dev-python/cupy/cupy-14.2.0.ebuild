# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
#
# Copied from 'stuff' overlay with some modifications.
# Add ROCm-7.2+ support.
#
# Cupy-14.x adds support for ROCm-7.x but drops support
# for ROCm-6.x, cuda-11 and cudnn (upstream recommends
# "cuDNN Frontend" for cuDNN functionality from Python).

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )
ROCM_VERSION=7.2.0
DISTUTILS_EXT=1
DISTUTILS_USE_PEP517=setuptools

inherit distutils-r1 prefix pypi rocm cuda

DESCRIPTION="NumPy-compatible array library accelerated by CUDA or ROCm"
HOMEPAGE="https://cupy.dev/"
SRC_URI="$(pypi_sdist_url "${PN^}" "${PV}")"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

# CuPy 14 moved cuDNN, cuSPARSELt, and cuTENSOR integrations to separate
# distributions; this core package follows its NumPy and CUDA-pathfinder bounds.
IUSE="rocm cuda"
REQUIRED_USE="
	^^ ( cuda rocm )
	rocm? ( ${ROCM_REQUIRED_USE} )
	"

DEPEND="
	>=dev-python/numpy-2.0[${PYTHON_USEDEP}]
	<dev-python/numpy-2.6[${PYTHON_USEDEP}]
	cuda? (
		dev-util/nvidia-cuda-toolkit[profiler]
		>=dev-python/cuda-pathfinder-1.3.4[${PYTHON_USEDEP}]
		<dev-python/cuda-pathfinder-2[${PYTHON_USEDEP}]
	)
	rocm? (
		>=dev-util/hip-${ROCM_VERSION}
		>=dev-util/roctracer-${ROCM_VERSION}
		>=sci-libs/hipBLAS-${ROCM_VERSION}:=[${ROCM_USEDEP},rocsolver]
		>=sci-libs/hipCUB-${ROCM_VERSION}:=[${ROCM_USEDEP}]
		>=sci-libs/hipFFT-${ROCM_VERSION}:=[${ROCM_USEDEP}]
		>=sci-libs/hipRAND-${ROCM_VERSION}:=[${ROCM_USEDEP}]
		>=sci-libs/rocThrust-${ROCM_VERSION}:=[${ROCM_USEDEP}]
		>=sci-libs/hipSPARSE-${ROCM_VERSION}:=[${ROCM_USEDEP}]
		>=sci-libs/hipSOLVER-${ROCM_VERSION}:=[${ROCM_USEDEP}]
	)
"
RDEPEND="${DEPEND}"
BDEPEND="
	>=dev-python/setuptools-77[${PYTHON_USEDEP}]
	dev-python/wheel[${PYTHON_USEDEP}]
	>=dev-python/cython-3.2[${PYTHON_USEDEP}]
"

EPYTEST_PLUGINS=()
distutils_enable_tests pytest

src_prepare() {
	default
	if use rocm; then
		eapply "${FILESDIR}/${P}-gentoo-rocm-defaults.patch"
		sed -i -e "s|@GENTOO_ROCM_ROOT@|${EPREFIX}/usr|g" \
			cupy/_environment.py || die
	fi
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
		local targets=() a
		if [[ -n ${NVPTX_TARGETS} ]]; then
			targets=( ${NVPTX_TARGETS} )
		elif [[ -n ${CUDAARCHS} ]]; then
			for a in ${CUDAARCHS//[;,]/ }; do
				targets+=( "sm_${a}" )
			done
		fi

		if [[ ${#targets[@]} -gt 0 ]]; then
			local supported=() codegen=()
			local s target ok

			while IFS= read -r s; do
				supported+=( "${s}" )
			done < <(nvcc --list-gpu-code) || die

			for target in "${targets[@]}"; do
				ok=
				for s in "${supported[@]}"; do
					[[ ${s} == "${target}" ]] && ok=1 && break
				done

				if [[ -n ${ok} ]]; then
					codegen+=( "arch=${target/sm_/compute_},code=${target}" )
				else
					ewarn "Skipping unsupported CUDA target ${target} for toolkit $(cuda_toolkit_version)"
				fi
			done

			[[ ${#codegen[@]} -gt 0 ]] \
				|| die "No supported CUDA targets (from NVPTX_TARGETS/CUDAARCHS)"

			local IFS=';'
			export CUPY_NVCC_GENERATE_CODE="${codegen[*]}"
		fi

		export NVCC="nvcc ${NVCCFLAGS}"
	fi
	distutils-r1_src_compile
}
