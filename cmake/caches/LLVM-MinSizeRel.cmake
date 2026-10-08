# cmake -G Ninja -S llvm-project/llvm -B build -C cmake/caches/LLVM-MinSizeRel.cmake
include(${CMAKE_CURRENT_LIST_DIR}/LLVM.cmake)

set(CMAKE_BUILD_TYPE MinSizeRel CACHE STRING "")

set(LLVM_DISTRIBUTION_COMPONENTS
  ${HYLO_LLVM_DISTRIBUTION_LIBRARIES}
  ${HYLO_LLVM_DISTRIBUTION_SUPPORT}
  lld
  llvm-config
  addr2line
  ar
  c++filt
  dsymutil
  dwp
  llvm-ar
  llvm-cov
  llvm-cvtres
  llvm-cxxfilt
  llvm-dlltool
  llvm-dwarfdump
  llvm-dwp
  llvm-lib
  llvm-lipo
  llvm-nm
  llvm-objcopy
  llvm-objdump
  llvm-pdbutil
  llvm-profdata
  llvm-ranlib
  llvm-rc
  llvm-readelf
  llvm-readobj
  llvm-size
  llvm-strings
  llvm-strip
  llvm-symbolizer
  llvm-undname
  nm
  objcopy
  objdump
  ranlib
  readelf
  size
  strings
  CACHE STRING "")
