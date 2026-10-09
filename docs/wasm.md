# The WebAssembly build

`llvm-<version>-wasm32-unknown-wasip1-swift<swift-version>-MinSizeRel.tar.zst` is LLVM built to run
inside WebAssembly, for the Hylo playground. It's built by
[`ci/build-llvm-wasi.ts`](../ci/build-llvm-wasi.ts), with the CMake configuration in
[`cmake/caches/LLVM-wasi.cmake`](../cmake/caches/LLVM-wasi.cmake) and
[`cmake/wasi-toolchain.cmake`](../cmake/wasi-toolchain.cmake).

## How it differs from the other packages

- It only has the WebAssembly target, plus lld's wasm port (`lldWasm`, `lldCommon` and headers).
- There's no `bin/`.
- It's built against the Swift wasm SDK, so it only works with that Swift version.
- The SDK's libc++ has threads disabled, which LLVM doesn't compile without. The package adds
  `libcxx-threads/__config_site` (which `llvm.pc` puts on the include path) and
  `lib/libc++threads.a` to turn them back on.

## The WASI host patch

Upstream LLVM doesn't build for a WASI host yet, so the build applies
[`patches/llvm-wasi-host.patch`](../patches/llvm-wasi-host.patch). The patch is based on
[llvm/llvm-project#92677](https://github.com/llvm/llvm-project/pull/92677), which is not merged,
as carried by [YoWASP](https://codeberg.org/YoWASP/llvm-project). The patch's header lists how it
differs from the PR.

The patch has to be ported to each new LLVM version. YoWASP's branches, one per major
version (such as `llvmorg-22.1.0+wasm`) plus `main+wasm`, are a good starting point.
