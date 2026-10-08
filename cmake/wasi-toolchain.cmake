# Cross-compiles to wasm32-wasip1 with the Swift toolchain's clang and the Swift wasm SDK. Expects
# SWIFT_BIN, WASI_SYSROOT, WASI_RESOURCE_DIR and LIBCXX_THREADS_INCLUDE in the environment; see
# scripts/build-llvm-wasi.sh.

# Platform/WASI is new in 3.31, and LLVM needs the WASI variable it sets.
if(CMAKE_VERSION VERSION_LESS 3.31)
  message(FATAL_ERROR "Cross-compiling to WASI requires CMake 3.31 or later, not ${CMAKE_VERSION}")
endif()

set(CMAKE_SYSTEM_NAME WASI)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR wasm32)

set(triple wasm32-unknown-wasip1)
set(CMAKE_C_COMPILER "$ENV{SWIFT_BIN}/clang")
set(CMAKE_CXX_COMPILER "$ENV{SWIFT_BIN}/clang++")
set(CMAKE_C_COMPILER_TARGET ${triple})
set(CMAKE_CXX_COMPILER_TARGET ${triple})
set(CMAKE_AR "$ENV{SWIFT_BIN}/llvm-ar")
set(CMAKE_RANLIB "$ENV{SWIFT_BIN}/llvm-ranlib")
set(CMAKE_SYSROOT "$ENV{WASI_SYSROOT}")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# The SDK's resource dir has the wasm32 builtins, which the toolchain's clang lacks. LLVM uses
# mmap, which wasi-libc only has in emulated form.
set(flags "-resource-dir=$ENV{WASI_RESOURCE_DIR} -D_WASI_EMULATED_MMAN -fno-exceptions")
set(CMAKE_C_FLAGS_INIT "${flags}")
# See scripts/build-libcxx-threads.sh.
set(CMAKE_CXX_FLAGS_INIT "${flags} -isystem $ENV{LIBCXX_THREADS_INCLUDE}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-resource-dir=$ENV{WASI_RESOURCE_DIR} -lwasi-emulated-mman")
