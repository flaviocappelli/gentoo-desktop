# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Copied from portage with some modifications.
# Add support for blis, cuda, flexiblas, openblas, opencl.

EAPI=8

ROCM_VERSION=7.2
inherit cmake cuda rocm toolchain-funcs

DESCRIPTION="Tensor library for machine learning"
HOMEPAGE="https://ggml.ai/"
SRC_URI="https://github.com/ggml-org/${PN}/archive/refs/tags/v${PV}.tar.gz
	-> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

X86_CPU_FLAGS=(
	avx
	avx_vnni
	avx2
	avx512bw
	avx512f
	avx512vbmi
	avx512_vnni
	bmi2
	fma3
	f16c
	sse4_2
)
CPU_FLAGS=( "${X86_CPU_FLAGS[@]/#/cpu_flags_x86_}" )
IUSE="${CPU_FLAGS[*]} blis cuda flexiblas openblas opencl openmp rocm test vulkan"

REQUIRED_USE="
	?? ( blis flexiblas openblas )
	rocm? ( ${ROCM_REQUIRED_USE} )
"

RESTRICT="!test? ( test )"

CDEPEND="
	blis? ( sci-libs/blis:= )
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
	flexiblas? ( sci-libs/flexiblas:= )
	openblas? ( sci-libs/openblas:= )
	rocm? (
		>=dev-util/hip-${ROCM_VERSION}:=
		>=sci-libs/hipBLAS-${ROCM_VERSION}:=
	)
	vulkan? ( media-libs/vulkan-loader )
"
DEPEND="${CDEPEND}
	opencl? ( dev-util/opencl-headers )
	vulkan? ( dev-util/vulkan-headers )
"
RDEPEND="${CDEPEND}
	opencl? ( dev-libs/opencl-icd-loader )
"

BDEPEND="vulkan? ( media-libs/shaderc )"

pkg_pretend() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
}

pkg_setup() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
}

src_prepare() {
	use cuda && cuda_src_prepare
	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DGGML_BACKEND_DL=OFF
		-DGGML_BUILD_EXAMPLES=OFF
		-DGGML_NATIVE=OFF
		-DGGML_HIP_MMQ_MFMA=OFF

		# CPU Flags
		-DGGML_AVX=$(usex cpu_flags_x86_avx)
		-DGGML_AVX_VNNI=$(usex cpu_flags_x86_avx_vnni)
		-DGGML_AVX2=$(usex cpu_flags_x86_avx2)
		-DGGML_AVX512_VBMI=$(usex cpu_flags_x86_avx512vbmi)
		-DGGML_AVX512_VNNI=$(usex cpu_flags_x86_avx512_vnni)
		-DGGML_BMI2=$(usex cpu_flags_x86_bmi2)
		-DGGML_FMA=$(usex cpu_flags_x86_fma3)
		-DGGML_F16C=$(usex cpu_flags_x86_f16c)
		-DGGML_SSE42=$(usex cpu_flags_x86_sse4_2)

		-DGGML_OPENMP=$(usex openmp)
		-DGGML_HIP=$(usex rocm)
		-DGGML_VULKAN=$(usex vulkan)

		-DGGML_CUDA=$(usex cuda)
		-DGGML_CUDA_NCCL=OFF		# Use ON only for multiple NVidia GPUs on the same host.
		-DGGML_OPENCL=$(usex opencl)

		-DGGML_BUILD_TESTS=$(usex test)
	)

	# Enable AVX512 if ANY of the avx512 flags are present
	if use cpu_flags_x86_avx512f || use cpu_flags_x86_avx512bw; then
		mycmakeargs+=( -DGGML_AVX512=ON )
	else
		mycmakeargs+=( -DGGML_AVX512=OFF )
	fi

	if use blis ; then
		mycmakeargs+=(
			-DGGML_BLAS=ON -DGGML_BLAS_VENDOR=FLAME
		)
	fi

	if use flexiblas; then
		mycmakeargs+=(
			-DGGML_BLAS=ON -DGGML_BLAS_VENDOR=FlexiBLAS
		)
	fi

	if use openblas ; then
		mycmakeargs+=(
			-DGGML_BLAS=ON -DGGML_BLAS_VENDOR=OpenBLAS
		)
	fi

	if use cuda; then
		local -x CUDAHOSTCXX="$(cuda_gccdir)"
		# tries to recreate dev symlinks
		cuda_add_sandbox
		addpredict "/dev/char/"
	fi

	cmake_src_configure
}
