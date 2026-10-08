# Hylo LLVM builds

GitHub CI based builds of LLVM libraries, compatible with the Swift
runtime.

These builds contain a set of libraries suitable for compiler
development and a very minimal set of tools; if you're looking for a compiler binary (e.g. `clang`), look elsewhere!

The build pipeline currently supports LLVM 23.1.0 and later. Pick a pre-built version from the
[releases](https://github.com/hylo-lang/llvm-build/releases), or fork the repo and trigger a build
workflow with a custom LLVM version (`X.Y.Z` part of an llvmorg tag).

Both the “Debug” and “MinSizeRel” builds have **assertions enabled**; 
without assertions, during development it's too easy to violate
LLVM's preconditions (some of which are 
[undocumented](https://github.com/llvm/llvm-project/pull/82519) or 
[incorrectly documented](https://github.com/llvm/llvm-project/pull/82517))

Swift compatibility is mostly irrelevant except when it comes to
Windows, where these builds of LLVM always link against a release-mode
multithreaded DLL C runtime and have iterator debugging disabled
(`_ITERATOR_DEBUG_LEVEL=0`) for C++.

To install these LLVM releases in CI, see the [get-llvm](https://github.com/hylo-lang/get-llvm/)
action. To install the releases in Docker, see https://github.com/hylo-lang/hylo-dev-toolchain. 

## What's in a release

Releases are tagged `llvm-<version>-<n>`. Older releases were tagged with a timestamp.

Release assets are named `llvm-<version>-<cpu>-<triple>-<configuration>.tar.zst` and are structured
as follows:

```
llvm-23.1.0-x86_64-unknown-linux-gnu-MinSizeRel/
 - bin/            tools (see below)
 - include/        LLVM headers
 - lib/            static libraries and CMake scripts
 - pkgconfig/
   - llvm.pc       relocatable pkg-config file
   - install-pc.sh
   - make-absolute-pc.sh
```

`Cflags` in `llvm.pc` only has the `-I` flag, since SwiftPM rejects anything else. If you need the
rest of LLVM's compile flags, get them from `llvm-config --cxxflags`.

The packages are meant for [Swifty-LLVM](https://github.com/hylo-lang/Swifty-LLVM), so they only
contain the libraries `llvm.pc` links, plus `llvm-config` and `lld`.

### WebAssembly

`llvm-<version>-wasm32-unknown-wasip1-swift<swift-version>-MinSizeRel.tar.zst` is LLVM built to run
inside WebAssembly, for the Hylo playground. Compared to the other packages:

- It only has the WebAssembly target, plus lld's wasm port (`lldWasm`, `lldCommon` and headers).
- It's built against the Swift wasm SDK, so it only works with that Swift version.
- The SDK's libc++ has threads disabled, which LLVM doesn't compile without. The package adds
  `libcxx-threads/__config_site` (which `llvm.pc` puts on the include path) and
  `lib/libc++threads.a` to turn them back on.
- There's no `bin/`.
- LLVM is [patched](patches/llvm-wasi-host.patch) to support WASI as a host. The patch comes from
  [YoWASP](https://github.com/YoWASP/llvm-project) and has to be ported to each LLVM version.

It's built by [`ci/build-llvm-wasi.mjs`](ci/build-llvm-wasi.mjs).

## Using a prebuilt release

Unpack the asset wherever you like. `pkgconfig/llvm.pc` is **relocatable**: all
paths in it are written relative to `${pcfiledir}/../`, so it keeps working if you relocate the llvm installation, as long as `llvm.pc` stays in `<prefix>/pkgconfig/`.

Then either point `pkg-config` at it directly:

```bash
export PKG_CONFIG_PATH="/path/to/llvm-23.1.0-.../pkgconfig:$PKG_CONFIG_PATH"
pkg-config --cflags --libs llvm
```

or install a copy into a directory `pkg-config` already searches, using the bundled script:

```bash
cd /path/to/llvm-23.1.0-.../pkgconfig
sudo ./install-pc.sh llvm.pc            # installs into /usr/local/lib/pkgconfig
```

Installing rewrites `${pcfiledir}` to an absolute path, because the installed copy no longer sits
next to the LLVM build. That means the installed `llvm.pc` is not relocatable: if you move or delete 
the unpacked build, re-run `install-pc.sh`.

## Build configuration

The CMake configuration is in [`cmake/caches/`](cmake/caches); the workflow only adds
platform-specific options. To build roughly what CI builds:

```sh
cmake -G Ninja -S llvm-project/llvm -B build -C cmake/caches/LLVM-MinSizeRel.cmake
cmake --build build --target install-distribution-stripped
```

## Scripts

The [`scripts/`](scripts) folder contains scripts that are useful either during the release workflow
or upon installation. See each script's in-source documentation header.

* [`make-pkgconfig.sh <path-to-pc-file>`](scripts/make-pkgconfig.sh): generates
  a relocatable `llvm.pc` for the LLVM build that the first `llvm-config` on
  `PATH` belongs to.
* [`make-absolute-pc.sh <path-to-pc-file>`](scripts/make-absolute-pc.sh):
  resolves `${pcfiledir}` in a `.pc` file to an absolute path, writing the
  result to stdout.
* [`install-pc.sh <path-to-pc-file> [destination-directory]`](scripts/install-pc.sh):
  installs a `.pc` file into a `pkg-config` search directory, making its paths
  absolute on the way.

The scripts in [`scripts/`](scripts) are shipped with the packages, so they stay in Bash. Code that
only runs in CI is in [`ci/`](ci), in JavaScript, with tests that run with `node --test ci/*.test.mjs`
on pull requests and before the release builds.

## Using an existing LLVM build with Swift

You can use a custom LLVM installation instead of our pre-built releases. LLVM
installations are missing a pkg-config file by default, which is required for the Swift Package
Manager to compile it as a dependency. You can generate this file yourself, using our provided 
scripts:

1. Put your build's `bin/` on `PATH` and confirm you picked up the right `llvm-config`:

   ```bash
   export PATH="/path/to/your/llvm/bin:$PATH"
   llvm-config --prefix --version
   ```

2. Generate the `.pc` file one directory below the prefix using 
   [make-pkgconfig.sh](./scripts/make-pkgconfig.sh):

   ```bash
   scripts/make-pkgconfig.sh "$(llvm-config --prefix)/pkgconfig/llvm.pc"
   ```

3. Make it visible to `pkg-config` in your shell:

   ```bash
   export PKG_CONFIG_PATH="$(llvm-config --prefix)/pkgconfig:$PKG_CONFIG_PATH"
   ```

   Or install it system-wide with
   `sudo scripts/install-pc.sh "$(llvm-config --prefix)/pkgconfig/llvm.pc"`, with the
   caveat described under [Using a prebuilt release](#using-a-prebuilt-release).

4. Check the result:

   ```bash
   pkg-config --cflags --libs llvm
   ```

> Note: On Windows, your LLVM build must use `_ITERATOR_DEBUG_LEVEL=0` and the release mode
> `MultiThreadedDLL` C runtime to link against the Swift runtime.
