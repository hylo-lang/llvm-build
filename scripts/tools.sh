#!/usr/bin/env sh
inputs_llvm_version=17.0.6
inputs_debug_info=false

matrix_os=macos-latest
matrix_c_compiler=clang
matrix_cxx_compiler=clang++
matrix_executable_suffix=

export SCCACHE_DIRECT=yes
github_workspace=/tmp/llvm-workspace


# Setup sccache
export SCCACHE_DIR=/tmp/sccache-${matrix_os}-build_tools

# Configure Tools
rm -f ${github_workspace}/BinaryCache/0/CMakeCache.txt

          cmake -B ${github_workspace}/BinaryCache/0 \
          -D CMAKE_BUILD_TYPE=Release \
          -D CMAKE_C_COMPILER=${matrix_c_compiler} \
          -D CMAKE_C_COMPILER_LAUNCHER=sccache \
          -D CMAKE_CXX_COMPILER=${matrix_cxx_compiler} \
          -D CMAKE_CXX_COMPILER_LAUNCHER=sccache \
          -D CMAKE_MT=mt \
          -G Ninja \
          -S ${github_workspace}/SourceCache/llvm-project/llvm \
          -D LLVM_ENABLE_ASSERTIONS=NO \
          -D LLVM_ENABLE_LIBEDIT=NO \
          -D LLVM_ENABLE_PROJECTS=""

# Build llvm-tblgen
        cmake --build ${github_workspace}/BinaryCache/0 --target llvm-tblgen
# Build llvm-config
        cmake --build ${github_workspace}/BinaryCache/0 --target llvm-config
