# Copyright 2024-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Copied from 'guru' overlay with some modifications.

EAPI=8

ROCM_VERSION=6.1
inherit cuda rocm
inherit cmake go-module systemd toolchain-funcs

DESCRIPTION="Get up and running with Llama 3, Mistral, Gemma, and other language models."
HOMEPAGE="https://ollama.com"

# by F.C.
# If there isn't a vendor tarball in "https://github.com/negril/gentoo-overlay-vendored"
# with the same version of this ebuild, it must be created by hand and moved into the
# folder "/var/cache/distfiles/" (do not forget to update the Manifest as well). See
# "Packaging the dependencies" in https://wiki.gentoo.org/wiki/Writing_go_Ebuilds
SRC_URI="
	https://github.com/ollama/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz
	https://github.com/negril/gentoo-overlay-vendored/raw/refs/heads/blobs/${P}-vendor.tar.xz
"
KEYWORDS="~amd64"
LICENSE="MIT"
SLOT="0"

X86_CPU_FLAGS=(
	avx
	f16c
	avx2
	fma3
	avx512f
	avx512vbmi
	avx512_vnni
	avx512_bf16
	avx_vnni
	amx_tile
	amx_int8
)
CPU_FLAGS=( "${X86_CPU_FLAGS[@]/#/cpu_flags_x86_}" )
IUSE="${CPU_FLAGS[*]} blas cuda mkl rocm systemd"

REQUIRED_USE="
	?? ( cuda rocm )
"

COMMON_DEPEND="
	blas? (
		!mkl? (
			virtual/blas
		)
		mkl? (
			sci-libs/mkl
		)
	)
	cuda? (
		dev-util/nvidia-cuda-toolkit:=
	)

	rocm? (
		>=sci-libs/hipBLAS-${ROCM_VERSION}:=[${ROCM_USEDEP}]
	)
	systemd? ( sys-apps/systemd )
"

DEPEND="
	${COMMON_DEPEND}
	>=dev-lang/go-1.23.4
"

RDEPEND="
	${COMMON_DEPEND}
	acct-group/ollama
	acct-user/ollama
"

PATCHES=(
	"${FILESDIR}/${PN}-0.6.3-use-GNUInstallDirs.patch"
)

pkg_pretend() {
	if use rocm; then
		einfo "Ollama with ROCm tested only on AMD Radeon RX 6900 XT (gfx1030, ROCm 6.3.3)"
	fi
	if use cuda; then
		einfo "Ollama with CUDA not tested, you are on your own (I don't have an NVidia GPU)"
	fi
}

src_unpack() {
	if [[ "${PV}" == *9999* ]]; then
		git-r3_src_unpack
		go-module_live_vendor
	else
		by F.C.
		# Enable these commands to stop this ebuild and prepare the vendor
		# blob tarball (also temporarily remove the blob URI from SRC_URI).
		#default
		#die
		go-module_src_unpack
	fi
}

src_prepare() {
	cmake_src_prepare

	sed \
		-e "/set(GGML_CCACHE/s/ON/OFF/g" \
		-e "/PRE_INCLUDE_REGEXES.*cu/d" \
		-e "/PRE_INCLUDE_REGEXES.*hip/d" \
		-i CMakeLists.txt || die sed

	sed \
		-e "s/ -O3//g" \
		-i ml/backend/ggml/ggml/src/ggml-cpu/cpu.go || die sed

	# fix library location
	sed \
		-e "s#lib/ollama#$(get_libdir)/ollama#g" \
		-i CMakeLists.txt || die sed

	sed \
		-e "s/\"..\", \"lib\"/\"..\", \"$(get_libdir)\"/" \
		-e "s#\"lib/ollama\"#\"$(get_libdir)/ollama\"#" \
		-i \
			ml/backend/ggml/ggml/src/ggml.go \
			discover/path.go \
		|| die

	if use amd64; then
		if ! use cpu_flags_x86_avx; then
			sed -e "/ggml_add_cpu_backend_variant(sandybridge/s/^/# /g" -i ml/backend/ggml/ggml/src/CMakeLists.txt || die
			# AVX)
		fi
		if
			! use cpu_flags_x86_avx ||
			! use cpu_flags_x86_f16c ||
			! use cpu_flags_x86_avx2 ||
			! use cpu_flags_x86_fma3; then
			sed -e "/ggml_add_cpu_backend_variant(haswell/s/^/# /g" -i ml/backend/ggml/ggml/src/CMakeLists.txt || die
			# AVX F16C AVX2 FMA)
		fi
		if
			! use cpu_flags_x86_avx ||
			! use cpu_flags_x86_f16c ||
			! use cpu_flags_x86_avx2 ||
			! use cpu_flags_x86_fma3 ||
			! use cpu_flags_x86_avx512f; then
			sed -e "/ggml_add_cpu_backend_variant(skylakex/s/^/# /g" -i ml/backend/ggml/ggml/src/CMakeLists.txt ||  die
			# AVX F16C AVX2 FMA AVX512)
		fi
		if
			! use cpu_flags_x86_avx ||
			! use cpu_flags_x86_f16c ||
			! use cpu_flags_x86_avx2 ||
			! use cpu_flags_x86_fma3 ||
			! use cpu_flags_x86_avx512f ||
			! use cpu_flags_x86_avx512vbmi ||
			! use cpu_flags_x86_avx512_vnni; then
			sed -e "/ggml_add_cpu_backend_variant(icelake/s/^/# /g" -i ml/backend/ggml/ggml/src/CMakeLists.txt || die
			# AVX F16C AVX2 FMA AVX512 AVX512_VBMI AVX512_VNNI)
		fi
		if
			! use cpu_flags_x86_avx ||
			! use cpu_flags_x86_f16c ||
			! use cpu_flags_x86_avx2 ||
			! use cpu_flags_x86_fma3 ||
			! use cpu_flags_x86_avx_vnni; then
			sed -e "/ggml_add_cpu_backend_variant(alderlake/s/^/# /g" -i ml/backend/ggml/ggml/src/CMakeLists.txt || die
			# AVX F16C AVX2 FMA AVX_VNNI)
		fi

		if
			! use cpu_flags_x86_avx ||
			! use cpu_flags_x86_f16c ||
			! use cpu_flags_x86_avx2 ||
			! use cpu_flags_x86_fma3 ||
			! use cpu_flags_x86_avx512f ||
			! use cpu_flags_x86_avx512vbmi ||
			! use cpu_flags_x86_avx512_vnni ||
			! use cpu_flags_x86_avx512_bf16 ||
			! use cpu_flags_x86_amx_tile ||
			! use cpu_flags_x86_amx_int8 ; then
			sed -e "/ggml_add_cpu_backend_variant(sapphirerapids/s/^/# /g" -i ml/backend/ggml/ggml/src/CMakeLists.txt || die
			#AVX F16C AVX2 FMA AVX512 AVX512_VBMI AVX512_VNNI AVX512_BF16 AMX_TILE AMX_INT8)
		fi
		: # ml/backend/ggml/ggml/src/CMakeLists.txt
	fi

	if use cuda; then
		cuda_src_prepare
	fi

	if use rocm; then
		# --hip-version gets appended to the compile flags which isn't a known flag.
		# This causes rocm builds to fail because -Wunused-command-line-argument is turned on.
		# Use nuclear option to fix this.
		# Disable -Werror's from go modules.
		find "${S}" -name ".go" -exec sed -i "s/ -Werror / /g" {} + || die
	fi
}

src_configure() {
	local mycmakeargs=(
		-DGGML_CCACHE="no"
		-DGGML_BLAS="$(usex blas)"
	)

	if use blas; then
		if use mkl; then
			mycmakeargs+=(
				-DGGML_BLAS_VENDOR="Intel"
			)
		else
			mycmakeargs+=(
				-DGGML_BLAS_VENDOR="Generic"
			)
		fi
	fi
	if use cuda; then
		local -x CUDAHOSTCXX CUDAHOSTLD
		CUDAHOSTCXX="$(cuda_gccdir)"
		CUDAHOSTLD="$(tc-getCXX)"

		cuda_add_sandbox -w
	else
		mycmakeargs+=(
			-DCMAKE_CUDA_COMPILER="NOTFOUND"
		)
	fi

	if use rocm; then
		mycmakeargs+=(
			-DCMAKE_HIP_ARCHITECTURES="$(get_amdgpu_flags)"
			-DCMAKE_HIP_PLATFORM="amd"
			# ollama doesn't honor the default cmake options
			-DAMDGPU_TARGETS="$(get_amdgpu_flags)"
		)

		local -x HIP_PATH="${ESYSROOT}/usr"

		check_amdgpu
	else
		mycmakeargs+=(
			-DCMAKE_HIP_COMPILER="NOTFOUND"
		)
	fi

	cmake_src_configure
}

src_compile() {
	ego build

	cmake_src_compile
}

src_install() {
	dobin ollama

	cmake_src_install

	if ! use systemd; then
		newinitd "${FILESDIR}/ollama.init" "${PN}"
		newconfd "${FILESDIR}/ollama.confd" "${PN}"
	else
		systemd_dounit "${FILESDIR}/ollama.service"
	fi
}

pkg_preinst() {
	keepdir /var/log/ollama
	fperms 755 /var/log/ollama
	fowners ollama:ollama /var/log/ollama
}

pkg_postinst() {
	if [[ -z ${REPLACING_VERSIONS} ]] ; then
		einfo "Quick guide:"
		einfo "\tollama serve"
		einfo "\tollama run llama3:70b"
		einfo
		einfo "See available models at https://ollama.com/library"
	fi

	einfo "When using CUDA or ROCm, the user running ollama has to be in the video group or it"
	einfo "will not detect the devices. The ebuild acct-user/ollama ensures this for user ollama."
}
