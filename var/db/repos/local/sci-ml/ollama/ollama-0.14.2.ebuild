# Copyright 2024-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# by F.C.
# Copied from 'guru' overlay with some modifications.

EAPI=8

ROCM_VERSION=6.2
inherit cmake cuda go-module linux-info rocm systemd toolchain-funcs

DESCRIPTION="Get up and running with Llama 3, Mistral, Gemma, and other language models"
HOMEPAGE="https://ollama.com"

SRC_URI="
	https://github.com/ollama/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz
	https://github.com/gentoo-golang-dist/${PN}/releases/download/v${PV}/${P}-deps.tar.xz
"

KEYWORDS="~amd64"
LICENSE="MIT"
SLOT="0"

X86_CPU_FLAGS=(
	sse4_2
	avx
	f16c
	avx2
	bmi2
	fma3
	avx512f
	avx512vbmi
	avx512_vnni
	avx_vnni
)

CPU_FLAGS=( "${X86_CPU_FLAGS[@]/#/cpu_flags_x86_}" )
IUSE="blas ${CPU_FLAGS[*]} cuda mkl rocm systemd vulkan"

REQUIRED_USE="
	?? ( cuda rocm )
"

RESTRICT="mirror test"

COMMON_DEPEND="
	blas? (
		!mkl? (
			virtual/blas
		)
		mkl? (
			sci-libs/mkl[llvm-openmp]
		)
	)
	cuda? (
		dev-util/nvidia-cuda-toolkit:=
	)
	rocm? (
		>=sci-libs/hipBLAS-${ROCM_VERSION}:=
	)
	systemd? ( sys-apps/systemd )
"

DEPEND="
	${COMMON_DEPEND}
	>=dev-lang/go-1.23.4
"
BDEPEND="
	vulkan? (
		dev-util/vulkan-headers
		media-libs/shaderc
	)
"

RDEPEND="
	${COMMON_DEPEND}
	acct-group/ollama
	>=acct-user/ollama-3-r1[cuda?]
"

PATCHES=(
	"${FILESDIR}/${PN}-9999-use-GNUInstallDirs.patch"
)

pkg_pretend() {
	if use amd64; then
		if use cpu_flags_x86_f16c && use cpu_flags_x86_avx2 && use cpu_flags_x86_fma3 && ! use cpu_flags_x86_bmi2; then
			ewarn
			ewarn "CPU_FLAGS_X86: bmi2 not enabled."
			ewarn "  Not building haswell runner."
			ewarn "  Not building skylakex runner."
			ewarn "  Not building icelake runner."
			ewarn "  Not building alderlake runner."
			ewarn
			if grep bmi2 /proc/cpuinfo > /dev/null; then
				ewarn "bmi2 found in /proc/cpuinfo"
				ewarn
			fi
		fi
	fi
}

pkg_setup() {
	if use rocm; then
		einfo "This ebuild has been tested with ROCM >= 6.4.3 on AMD Radeon RX 6900 XT only"
		linux-info_pkg_setup
		if linux-info_get_any_version && linux_config_exists; then
			if ! linux_chkconfig_present HSA_AMD_SVM; then
				ewarn "To use ROCm/HIP, you need to have HSA_AMD_SVM option enabled in your kernel."
			fi
		fi
	fi
	if use cuda; then
		einfo "This ebuild has not yet been tested with CUDA (I don't have an NVidia GPU)"
	fi
}

src_unpack() {
	# Already filter lto flags for ROCM
	# 963401
	if use rocm; then
		# copied from _rocm_strip_unsupported_flags
		strip-unsupported-flags
		export CXXFLAGS="$(test-flags-HIPCXX "${CXXFLAGS}")"
	fi
	go-module_src_unpack
}

src_prepare() {
	cmake_src_prepare

	sed \
		-e "/set(GGML_CCACHE/s/ON/OFF/g" \
		-e "/PRE_INCLUDE_REGEXES.*cu/d" \
		-e "/PRE_INCLUDE_REGEXES.*hip/d" \
		-i CMakeLists.txt || die "bundle headers sed failed"

	sed \
		-e "s/ -O3//g" \
		-i ml/backend/ggml/ggml/src/ggml-cpu/cpu.go || die "-O3 sed failed"

	sed \
		-e "s#\"..\", \"lib\"#\"..\", \"$(get_libdir)\"#" \
		-e "s#\"lib/ollama\"#\"$(get_libdir)/ollama\"#" \
		-i \
			ml/backend/ggml/ggml/src/ggml.go \
			ml/path.go \
		|| die "libdir sed failed"

	if use amd64; then
		if
			! use cpu_flags_x86_sse4_2; then
			sed -e "/ggml_add_cpu_backend_variant(sse42/s/^/# /g" -i ml/backend/ggml/ggml/src/CMakeLists.txt || die
			# SSE42)
		fi
		if
			! use cpu_flags_x86_sse4_2 ||
			! use cpu_flags_x86_avx; then
			sed -e "/ggml_add_cpu_backend_variant(sandybridge/s/^/# /g" -i ml/backend/ggml/ggml/src/CMakeLists.txt || die
			# SSE42 AVX)
		fi
		if
			! use cpu_flags_x86_sse4_2 ||
			! use cpu_flags_x86_avx ||
			! use cpu_flags_x86_f16c ||
			! use cpu_flags_x86_avx2 ||
			! use cpu_flags_x86_bmi2 ||
			! use cpu_flags_x86_fma3; then
			sed -e "/ggml_add_cpu_backend_variant(haswell/s/^/# /g" -i ml/backend/ggml/ggml/src/CMakeLists.txt || die
			# SSE42 AVX F16C AVX2 BMI2 FMA)
		fi
		if
			! use cpu_flags_x86_sse4_2 ||
			! use cpu_flags_x86_avx ||
			! use cpu_flags_x86_f16c ||
			! use cpu_flags_x86_avx2 ||
			! use cpu_flags_x86_bmi2 ||
			! use cpu_flags_x86_fma3 ||
			! use cpu_flags_x86_avx512f; then
			sed -e "/ggml_add_cpu_backend_variant(skylakex/s/^/# /g" -i ml/backend/ggml/ggml/src/CMakeLists.txt ||  die
			# SSE42 AVX F16C AVX2 BMI2 FMA AVX512)
		fi
		if
			! use cpu_flags_x86_sse4_2 ||
			! use cpu_flags_x86_avx ||
			! use cpu_flags_x86_f16c ||
			! use cpu_flags_x86_avx2 ||
			! use cpu_flags_x86_bmi2 ||
			! use cpu_flags_x86_fma3 ||
			! use cpu_flags_x86_avx512f ||
			! use cpu_flags_x86_avx512vbmi ||
			! use cpu_flags_x86_avx512_vnni; then
			sed -e "/ggml_add_cpu_backend_variant(icelake/s/^/# /g" -i ml/backend/ggml/ggml/src/CMakeLists.txt || die
			# SSE42 AVX F16C AVX2 BMI2 FMA AVX512 AVX512_VBMI AVX512_VNNI)
		fi
		if
			! use cpu_flags_x86_sse4_2 ||
			! use cpu_flags_x86_avx ||
			! use cpu_flags_x86_f16c ||
			! use cpu_flags_x86_avx2 ||
			! use cpu_flags_x86_bmi2 ||
			! use cpu_flags_x86_fma3 ||
			! use cpu_flags_x86_avx_vnni; then
			sed -e "/ggml_add_cpu_backend_variant(alderlake/s/^/# /g" -i ml/backend/ggml/ggml/src/CMakeLists.txt || die
			# SSE42 AVX F16C AVX2 BMI2 FMA AVX_VNNI)
		fi
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

		# backends end up in /usr/bin otherwise
		-DGGML_BACKEND_DL="yes"
		-DGGML_BACKEND_DIR="${EPREFIX}/usr/$(get_libdir)/${PN}"

		-DGGML_BLAS="$(usex blas)"
		"$(cmake_use_find_package vulkan Vulkan)"
	)

	if use blas; then
		if use mkl; then
			mycmakeargs+=(
				-DGGML_BLAS_VENDOR="Intel10_64lp"
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

		# default to all for now until cuda.eclass is updated
		if [[ ! -v CUDAARCHS ]]; then
			local CUDAARCHS="all"
		fi

		mycmakeargs+=(
			-DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
		)

		cuda_add_sandbox -w
		addpredict "/dev/char/"
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
	# export version information
	# https://github.com/gentoo/guru/pull/205
	# https://forums.gentoo.org/viewtopic-p-8831646.html
	local VERSION
	VERSION="${PVR}"
	local EXTRA_GOFLAGS_LD=(
		# "-w" # disable DWARF generation
		# "-s" # disable symbol table
		"-X=github.com/ollama/ollama/version.Version=${VERSION}"
		"-X=github.com/ollama/ollama/server.mode=release"
	)
	GOFLAGS+=" '-ldflags=${EXTRA_GOFLAGS_LD[*]}'"

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
	einfo "Remember to enable (or restart) the ollama service."

	if use cuda ; then
		einfo
		einfo "When using CUDA, the user 'ollama' has to be in the 'video' group or it"
		einfo "won't detect the GPU. The ebuild ensures this via 'acct-user/ollama[cuda]'."
	fi

	einfo
	einfo "See available models at https://ollama.com/library"
}
