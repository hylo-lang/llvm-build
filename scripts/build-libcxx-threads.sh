#!/usr/bin/env bash

# The Swift wasm SDK's libc++ is built without threads, but LLVM uses std::mutex and friends even
# with LLVM_ENABLE_THREADS=OFF. This writes a __config_site that enables threads on top of
# wasi-libc's pthread stubs, and builds the parts of libc++ that need to be compiled for that
# (from the libc++ version the SDK ships) into libc++threads.a.
#
# Usage: build-libcxx-threads.sh <output-dir>
#
# Needs SWIFT_BIN, WASI_SYSROOT and WASI_RESOURCE_DIR (see swift-wasm-sdk-env.sh).

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <output-directory>" >&2
    exit 1
fi

output=$1
triple=wasm32-unknown-wasip1

# e.g. 210106 for 21.1.6
libcxx_version=$(sed -n -E 's/^# *define _LIBCPP_VERSION ([0-9]+)$/\1/p' "$WASI_SYSROOT/include/c++/v1/__config")
if [ -z "$libcxx_version" ]; then
    echo "Error: no _LIBCPP_VERSION in $WASI_SYSROOT/include/c++/v1/__config" >&2
    exit 1
fi
libcxx_tag="llvmorg-$((libcxx_version / 10000)).$((libcxx_version / 100 % 100)).$((libcxx_version % 100))"
echo "Building libc++ thread support from $libcxx_tag"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
source="$work/llvm-project"
staging="$work/output"
git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$libcxx_tag" --filter=blob:none --sparse \
    https://github.com/llvm/llvm-project.git "$source"
git -C "$source" sparse-checkout set libcxx

mkdir -p "$staging/include" "$staging/obj"

sed -e 's/#define _LIBCPP_HAS_THREADS 0/#define _LIBCPP_HAS_THREADS 1/' \
    -e 's/#define _LIBCPP_HAS_THREAD_API_PTHREAD 0/#define _LIBCPP_HAS_THREAD_API_PTHREAD 1/' \
    "$WASI_SYSROOT/include/c++/v1/__config_site" > "$staging/include/__config_site"
if ! grep -q '#define _LIBCPP_HAS_THREADS 1' "$staging/include/__config_site" ||
   ! grep -q '#define _LIBCPP_HAS_THREAD_API_PTHREAD 1' "$staging/include/__config_site"; then
    echo "Error: the SDK's __config_site no longer has the expected thread settings" >&2
    exit 1
fi

for f in mutex mutex_destructor condition_variable condition_variable_destructor future \
         shared_mutex thread atomic barrier; do
    "$SWIFT_BIN/clang++" --target="$triple" --sysroot="$WASI_SYSROOT" \
        -resource-dir="$WASI_RESOURCE_DIR" -isystem "$staging/include" \
        -std=c++23 -Os -fno-exceptions -DNDEBUG -D_LIBCPP_BUILDING_LIBRARY \
        -I"$source/libcxx/src" \
        -c "$source/libcxx/src/$f.cpp" -o "$staging/obj/$f.o"
done
"$SWIFT_BIN/llvm-ar" rcs "$staging/libc++threads.a" "$staging"/obj/*.o

# Leave unchanged files alone, or an incremental LLVM build recompiles everything.
mkdir -p "$output/include"
for file in include/__config_site libc++threads.a; do
    if ! cmp -s "$staging/$file" "$output/$file"; then
        cp "$staging/$file" "$output/$file"
    fi
done
