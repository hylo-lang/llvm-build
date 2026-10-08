# cmake -G Ninja -S llvm-project/llvm -B build -C cmake/caches/LLVM-Debug.cmake
include(${CMAKE_CURRENT_LIST_DIR}/LLVM.cmake)

set(CMAKE_BUILD_TYPE Debug CACHE STRING "")

# Embed the debug info, since PDBs don't get installed.
set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT Embedded CACHE STRING "")

set(LLVM_DISTRIBUTION_COMPONENTS
  ${HYLO_LLVM_DISTRIBUTION_LIBRARIES}
  ${HYLO_LLVM_DISTRIBUTION_SUPPORT}
  ${HYLO_LLVM_DISTRIBUTION_TOOLS}
  CACHE STRING "")
