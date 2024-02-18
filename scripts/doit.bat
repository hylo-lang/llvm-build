call vcvarsarm64.bat
@echo on

set LLVM_VERSION=17.0.6
set SCCACHE_DIRECT=yes
set WORKSPACE=s:\build\llvm
mkdir %WORKSPACE%

set LLVM_SOURCE=s:\src\llvm-17.0.6
set LLVM_BUILD_SOURCE=s:\src\llvm-build
set SCCACHE_DIR=s:\sccache

          cmake -B %WORKSPACE%/BinaryCache/0 ^
                -D CMAKE_BUILD_TYPE=Release ^
                -D CMAKE_C_COMPILER=cl ^
                -D CMAKE_C_COMPILER_LAUNCHER=sccache ^
                -D CMAKE_CXX_COMPILER=cl ^
                -D CMAKE_CXX_COMPILER_LAUNCHER=sccache ^
                -D CMAKE_MT=mt ^
                -G Ninja ^
                -S %LLVM_SOURCE%/llvm ^
                -D LLVM_ENABLE_ASSERTIONS=NO ^
                -D LLVM_ENABLE_LIBEDIT=NO ^
                -D LLDB_ENABLE_PYTHON=NO ^
                -D LLDB_INCLUDE_TESTS=NO
if %errorlevel% neq 0 exit /b %errorlevel%

        cmake --build %WORKSPACE%/BinaryCache/0 --target llvm-tblgen
if %errorlevel% neq 0 exit /b %errorlevel%
        cmake --build %WORKSPACE%/BinaryCache/0 --target lldb-tblgen
if %errorlevel% neq 0 exit /b %errorlevel%
        cmake --build %WORKSPACE%/BinaryCache/0 --target llvm-config
if %errorlevel% neq 0 exit /b %errorlevel%

set ARCH=arm64
set CPU=aarch64
set TRIPLE=aarch64-unknown-windows-msvc

set PYTHON_VERSION=3.11.5
set LLVM_CONFIG=llvm-%LLVM_VERSION%-%ARCH%-msvc17-release

set PYTHON_LOCATION_arm64=C:\Users\dave\AppData\Local\Programs\Python\Python311-arm64

set CMAKE_SYSTEM_NAME="-D CMAKE_SYSTEM_NAME=Windows"
set CMAKE_SYSTEM_PROCESSOR="-D CMAKE_SYSTEM_PROCESSOR=ARM64"
set CACHE="Windows-aarch64.cmake"

mkdir %WORKSPACE%/BinaryCache/1

powershell -Command "cygpath -m (Split-Path (Get-Command clang-cl).Source)">%WORKSPACE%\clang-cl-dir
if %errorlevel% neq 0 exit /b %errorlevel%
set /p CLANG_LOCATION=<%WORKSPACE%\clang-cl-dir

          cmake -B %WORKSPACE%/BinaryCache/1 ^
                -C %LLVM_BUILD_SOURCE%/cmake/caches/%CACHE% ^
                -D CMAKE_BUILD_TYPE=Release ^
                -D CMAKE_C_COMPILER=cl ^
                -D CMAKE_C_COMPILER_LAUNCHER=sccache ^
                -D CMAKE_CXX_COMPILER=cl ^
                -D CMAKE_CXX_COMPILER_LAUNCHER=sccache ^
                -D CMAKE_MT=mt ^
                -D CMAKE_INSTALL_PREFIX=%WORKSPACE%/BuildRoot/%LLVM_CONFIG% ^
                %CMAKE_SYSTEM_NAME% ^
                %CMAKE_SYSTEM_PROCESSOR% ^
                -G Ninja ^
                -S %LLVM_SOURCE%/llvm ^
                -D LLDB_TABLEGEN=%WORKSPACE%/BinaryCache/0/bin/lldb-tblgen.exe ^
                -D LLVM_CONFIG_PATH=%WORKSPACE%/BinaryCache/0/bin/llvm-config.exe ^
                -D LLVM_NATIVE_TOOL_DIR=%WORKSPACE%/BinaryCache/0/bin ^
                -D LLVM_TABLEGEN=%WORKSPACE%/BinaryCache/0/bin/llvm-tblgen.exe ^
                -D LLVM_USE_HOST_TOOLS=NO ^
                -D PACKAGE_VENDOR=compnerd.org ^
                -D LLVM_PARALLEL_LINK_JOBS=2 ^
                -D LLVM_APPEND_VC_REV=NO ^
                -D LLVM_VERSION_SUFFIX="" ^
                -D LLDB_PYTHON_EXE_RELATIVE_PATH=python.exe ^
                -D LLDB_PYTHON_EXT_SUFFIX=.pyd ^
                -D LLDB_PYTHON_RELATIVE_PATH=lib/site-packages ^
                -D Python3_EXECUTABLE=%PYTHON_LOCATION_arm64%\python.exe ^
                -D Python3_INCLUDE_DIR=%PYTHON_LOCATION_arm64%\include ^
                -D Python3_LIBRARY=%PYTHON_LOCATION_arm64%\libs\python311.lib ^
                -D Python3_ROOT_DIR=%PYTHON_LOCATION_arm64% ^
		--trace-expand --trace-redirect s:/cmake-trace.txt
if %errorlevel% neq 0 exit /b %errorlevel%

        cmake --build %WORKSPACE%/BinaryCache/1 --target distribution
if %errorlevel% neq 0 exit /b %errorlevel%

        cmake --build %WORKSPACE%/BinaryCache/1 --target install-distribution-stripped
if %errorlevel% neq 0 exit /b %errorlevel%
