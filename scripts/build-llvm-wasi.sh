#!/usr/bin/env bash

# Builds LLVM (WebAssembly target only) and lld's wasm port for wasm32-unknown-wasip1, and installs
# them to <install-prefix> together with a relocatable pkgconfig/llvm.pc.
#
# Usage: build-llvm-wasi.sh <llvm-source> <native-tool-dir> <build-dir> <install-prefix>
#
#   <llvm-source>      llvm-project, with patches/llvm-wasi-host.patch applied
#   <native-tool-dir>  llvm-tblgen and llvm-min-tblgen built for the build machine
#
# Needs SWIFT_BIN, WASI_SYSROOT and WASI_RESOURCE_DIR (see swift-wasm-sdk-env.sh), CMake 3.31 or
# later, ninja and git. For example:
#
#   export $(scripts/swift-wasm-sdk-env.sh swift-6.3.2-RELEASE_wasm)
#   scripts/build-llvm-wasi.sh llvm-project native/bin build install

set -euo pipefail

if [ $# -ne 4 ]; then
    echo "Usage: $0 <llvm-source> <native-tool-dir> <build-dir> <install-prefix>" >&2
    exit 1
fi

scripts=$(cd "$(dirname "$0")" && pwd)
source_dir=$1
native_tools=$2
build=$3
prefix=$4

# What Swifty-LLVM needs for the WebAssembly target, and lld for linking in-process.
targets=(
    LLVMCore LLVMSupport LLVMAnalysis LLVMBitWriter LLVMPasses LLVMTarget LLVMTargetParser
    LLVMWebAssemblyCodeGen LLVMWebAssemblyAsmParser LLVMWebAssemblyDisassembler
    LLVMWebAssemblyDesc LLVMWebAssemblyInfo LLVMWebAssemblyUtils
    lldWasm lldCommon
)

"$scripts/build-libcxx-threads.sh" "$build/libcxx-threads"
export LIBCXX_THREADS_INCLUDE="$build/libcxx-threads/include"

cmake -G Ninja -S "$source_dir/llvm" -B "$build/llvm" \
    -C "$scripts/../cmake/caches/LLVM-wasi.cmake" \
    -D LLVM_NATIVE_TOOL_DIR="$native_tools" \
    -D CMAKE_INSTALL_PREFIX="$prefix"
ninja -C "$build/llvm" "${targets[@]}"

rm -rf "$prefix"
ninja -C "$build/llvm" install-llvm-headers install-lld-headers
mkdir -p "$prefix/lib"
cp "$build/llvm"/lib/*.a "$build/libcxx-threads/libc++threads.a" "$prefix/lib/"
mkdir -p "$prefix/libcxx-threads"
cp "$build/libcxx-threads/include/__config_site" "$prefix/libcxx-threads/"

version=$(sed -n -E 's/^#define LLVM_VERSION_STRING "([^"]+)"$/\1/p' "$prefix/include/llvm/Config/llvm-config.h")
"$scripts/make-pkgconfig.sh" --installed-libraries "$version" "$prefix/pkgconfig/llvm.pc" libcxx-threads
