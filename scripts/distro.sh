#!/usr/bin/env sh
set -x
set -e
set -o pipefail

inputs_llvm_version=20.1.7
inputs_debug_info=false

matrix_os=macos-latest
matrix_c_compiler=clang
matrix_cxx_compiler=clang++
matrix_executable_suffix=
matrix_toolset_suffix=
matrix_cmake_system_name="-D CMAKE_SYSTEM_NAME=Darwin"
matrix_cmake_system_processor="-D CMAKE_SYSTEM_PROCESSOR=ARM64"
matrix_into_environment='>> $GITHUB_ENV'
matrix_executable_suffix=
matrix_llvm_enable_projects='lld'
matrix_arch=arm64
matrix_triple_cpu=arm64
matrix_triple_suffix=apple-darwin23.3.0
matrix_static_lib_suffix=.a
matrix_package_command="tar cjf"
matrix_package_suffix=.tar.bz2
matrix_compile_cache=ccache
matrix_llvm_target_arch=ARM64

export SCCACHE_DIRECT=yes
github_workspace=/tmp/llvm-workspace

export TARGET_TRIPLE=${matrix_triple_cpu}-${matrix_triple_suffix}
export LLVM_CONFIG=llvm-${matrix_triple_cpu}-${matrix_triple_suffix}-release

# Setup sccache
export SCCACHE_DIR=/tmp/sccache-${matrix_os}-${matrix_arch}-distribution
export CCACHE_DIR=/tmp/sccache-${matrix_os}-${matrix_arch}-distribution

# Configure LLVM
#rm -f ${github_workspace}/BinaryCache/1/CMakeCache.txt

          cmake -GNinja ${matrix_cmake_system_name} ${matrix_cmake_system_processor} \
	  --toolchain ~/src/llvm-build/cmake/toolchains/Darwin-arm64.cmake \
          -B ${github_workspace}/BinaryCache/1 \
          -C ${github_workspace}/SourceCache/llvm-build/cmake/caches/LLVM.cmake \
          -D CMAKE_BUILD_TYPE=Release \
          -D CMAKE_C_COMPILER_LAUNCHER=${matrix_compile_cache} \
          -D CMAKE_CXX_COMPILER_LAUNCHER=${matrix_compile_cache} \
          -D CMAKE_MT=mt \
          -D CMAKE_INSTALL_PREFIX=${github_workspace}/BuildRoot/${PACKAGE_NAME} \
          -S ${github_workspace}/SourceCache/llvm-project/llvm \
          -D CLANG_TABLEGEN=${github_workspace}/BinaryCache/0/bin/clang-tblgen${matrix_executable_suffix} \
          -D CLANG_TIDY_CONFUSABLE_CHARS_GEN=${github_workspace}/BinaryCache/0/bin/clang-tidy-confusable-chars-gen${matrix_executable_suffix} \
          -D LLVM_CONFIG_PATH=${github_workspace}/BinaryCache/0/bin/llvm-config${matrix_executable_suffix} \
          -D LLVM_NATIVE_TOOL_DIR=${github_workspace}/BinaryCache/0/bin \
          -D LLVM_TABLEGEN=${github_workspace}/BinaryCache/0/bin/llvm-tblgen${matrix_executable_suffix} \
          -D LLVM_USE_HOST_TOOLS=NO \
          -D CLANG_VENDOR=hylo-lang.org \
          -D CLANG_VENDOR_UTI=org.hylo-lang.dt \
          -D PACKAGE_VENDOR=hylo-lang.org \
          -D LLVM_DEFAULT_TARGET_TRIPLE=${TARGET_TRIPLE} \
	  -D LLVM_ENABLE_ZSTD=NO \
          -D LLVM_HOST_TRIPLE=${TARGET_TRIPLE} \
	  -D LLVM_TARGET_ARCH=${matrix_llvm_target_arch} \
          -D LLVM_ENABLE_PROJECTS="${matrix_llvm_enable_projects}" \
          -D LLVM_PARALLEL_LINK_JOBS=2 \
          -D LLVM_APPEND_VC_REV=NO \
          -D LLVM_VERSION_SUFFIX=""

# Build LLVM
        cmake --build ${github_workspace}/BinaryCache/1

# Install LLVM
        cmake --build ${github_workspace}/BinaryCache/1 --target install

# Upload LLVM

# Package LLVM
          7z a -t7z ${LLVM_CONFIG}.7z ${github_workspace}\BuildRoot\${LLVM_CONFIG}
