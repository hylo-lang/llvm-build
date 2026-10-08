# NOTE(compnerd) always enable assertions, the toolchain will not provide enough
# context to resolve issues otherwise and may silently generate invalid output.
set(LLVM_ENABLE_ASSERTIONS YES CACHE BOOL "")

set(ENABLE_X86_RELAX_RELOCATIONS YES CACHE BOOL "")
set(LLVM_ENABLE_ZSTD NO CACHE BOOL "")

set(LLVM_APPEND_VC_REV NO CACHE BOOL "")
set(LLVM_ENABLE_PER_TARGET_RUNTIME_DIR YES CACHE BOOL "")

set(LLVM_TARGETS_TO_BUILD all CACHE STRING "")

# Disable certain targets to reduce the configure time or to avoid configuration
# differences (and in some cases weird build errors on a complete build).
set(LLVM_BUILD_LLVM_DYLIB NO CACHE BOOL "")
set(LLVM_BUILD_LLVM_C_DYLIB NO CACHE BOOL "")
set(LLVM_BUILD_TESTS NO CACHE BOOL "Build LLVM unit tests. If OFF, just generate build targets.")
set(LLVM_ENABLE_LIBEDIT NO CACHE BOOL "")
set(LLVM_ENABLE_LIBXML2 NO CACHE BOOL "")
set(LLVM_ENABLE_OCAMLDOC NO CACHE BOOL "")
set(LLVM_ENABLE_TERMINFO NO CACHE BOOL "")
set(LLVM_ENABLE_Z3_SOLVER NO CACHE BOOL "")
set(LLVM_ENABLE_ZLIB NO CACHE BOOL "")
# The DIA SDK needs ATL, which the 14.44 toolset lacks on windows-11-arm. LLVM reads PDBs natively.
set(LLVM_ENABLE_DIA_SDK NO CACHE BOOL "")
set(LLVM_INCLUDE_BENCHMARKS NO CACHE BOOL "")
set(LLVM_INCLUDE_DOCS NO CACHE BOOL "")
set(LLVM_INCLUDE_EXAMPLES NO CACHE BOOL "")
set(LLVM_INCLUDE_GO_TESTS NO CACHE BOOL "")
set(LLVM_INCLUDE_TESTS NO CACHE BOOL "Generate build targets for the LLVM unit tests.")
set(LLVM_TOOL_GOLD_BUILD NO CACHE BOOL "")
set(LLVM_TOOL_LLVM_SHLIB_BUILD NO CACHE BOOL "")

set(LLVM_ENABLE_PROJECTS lld CACHE STRING "")
set(LLVM_USE_HOST_TOOLS NO CACHE BOOL "")
set(LLVM_PARALLEL_LINK_JOBS 2 CACHE STRING "")
set(LLVM_VERSION_SUFFIX "" CACHE STRING "")
set(PACKAGE_VENDOR hylo-lang.org CACHE STRING "")

# The libraries llvm.pc links (see scripts/make-pkgconfig.sh). After an LLVM upgrade, regenerate
# the list with
#   llvm-config --libnames core analysis bitwriter passes target all-targets
set(HYLO_LLVM_DISTRIBUTION_LIBRARIES
  LLVMAArch64AsmParser
  LLVMAArch64CodeGen
  LLVMAArch64Desc
  LLVMAArch64Disassembler
  LLVMAArch64Info
  LLVMAArch64Utils
  LLVMAMDGPUAsmParser
  LLVMAMDGPUCodeGen
  LLVMAMDGPUDesc
  LLVMAMDGPUDisassembler
  LLVMAMDGPUInfo
  LLVMAMDGPUTargetMCA
  LLVMAMDGPUUtils
  LLVMARMAsmParser
  LLVMARMCodeGen
  LLVMARMDesc
  LLVMARMDisassembler
  LLVMARMInfo
  LLVMARMUtils
  LLVMAVRAsmParser
  LLVMAVRCodeGen
  LLVMAVRDesc
  LLVMAVRDisassembler
  LLVMAVRInfo
  LLVMAggressiveInstCombine
  LLVMAnalysis
  LLVMAsmParser
  LLVMAsmPrinter
  LLVMBPFAsmParser
  LLVMBPFCodeGen
  LLVMBPFDesc
  LLVMBPFDisassembler
  LLVMBPFInfo
  LLVMBinaryFormat
  LLVMBitReader
  LLVMBitWriter
  LLVMBitstreamReader
  LLVMCFGuard
  LLVMCGData
  LLVMCodeGen
  LLVMCodeGenTypes
  LLVMCore
  LLVMCoroutines
  LLVMDebugInfoBTF
  LLVMDebugInfoCodeView
  LLVMDebugInfoDWARF
  LLVMDebugInfoDWARFLowLevel
  LLVMDebugInfoGSYM
  LLVMDebugInfoMSF
  LLVMDebugInfoPDB
  LLVMDemangle
  LLVMFrontendAtomic
  LLVMFrontendDirective
  LLVMFrontendHLSL
  LLVMFrontendOffloading
  LLVMFrontendOpenMP
  LLVMGlobalISel
  LLVMHexagonAsmParser
  LLVMHexagonCodeGen
  LLVMHexagonDesc
  LLVMHexagonDisassembler
  LLVMHexagonInfo
  LLVMHipStdPar
  LLVMIRPrinter
  LLVMIRReader
  LLVMInstCombine
  LLVMInstrumentation
  LLVMLanaiAsmParser
  LLVMLanaiCodeGen
  LLVMLanaiDesc
  LLVMLanaiDisassembler
  LLVMLanaiInfo
  LLVMLinker
  LLVMLoongArchAsmParser
  LLVMLoongArchCodeGen
  LLVMLoongArchDesc
  LLVMLoongArchDisassembler
  LLVMLoongArchInfo
  LLVMMC
  LLVMMCA
  LLVMMCDisassembler
  LLVMMCParser
  LLVMMIRParser
  LLVMMSP430AsmParser
  LLVMMSP430CodeGen
  LLVMMSP430Desc
  LLVMMSP430Disassembler
  LLVMMSP430Info
  LLVMMipsAsmParser
  LLVMMipsCodeGen
  LLVMMipsDesc
  LLVMMipsDisassembler
  LLVMMipsInfo
  LLVMNVPTXCodeGen
  LLVMNVPTXDesc
  LLVMNVPTXInfo
  LLVMObjCARCOpts
  LLVMObject
  LLVMObjectYAML
  LLVMPasses
  LLVMPowerPCAsmParser
  LLVMPowerPCCodeGen
  LLVMPowerPCDesc
  LLVMPowerPCDisassembler
  LLVMPowerPCInfo
  LLVMProfileData
  LLVMRISCVAsmParser
  LLVMRISCVCodeGen
  LLVMRISCVDesc
  LLVMRISCVDisassembler
  LLVMRISCVInfo
  LLVMRISCVTargetMCA
  LLVMRemarks
  LLVMSPIRVAnalysis
  LLVMSPIRVCodeGen
  LLVMSPIRVDesc
  LLVMSPIRVInfo
  LLVMSandboxIR
  LLVMScalarOpts
  LLVMSelectionDAG
  LLVMSparcAsmParser
  LLVMSparcCodeGen
  LLVMSparcDesc
  LLVMSparcDisassembler
  LLVMSparcInfo
  LLVMSupport
  LLVMSymbolize
  LLVMSystemZAsmParser
  LLVMSystemZCodeGen
  LLVMSystemZDesc
  LLVMSystemZDisassembler
  LLVMSystemZInfo
  LLVMTarget
  LLVMTargetParser
  LLVMTextAPI
  LLVMTransformUtils
  LLVMVEAsmParser
  LLVMVECodeGen
  LLVMVEDesc
  LLVMVEDisassembler
  LLVMVEInfo
  LLVMVectorize
  LLVMWebAssemblyAsmParser
  LLVMWebAssemblyCodeGen
  LLVMWebAssemblyDesc
  LLVMWebAssemblyDisassembler
  LLVMWebAssemblyInfo
  LLVMWebAssemblyUtils
  LLVMX86AsmParser
  LLVMX86CodeGen
  LLVMX86Desc
  LLVMX86Disassembler
  LLVMX86Info
  LLVMX86TargetMCA
  LLVMXCoreCodeGen
  LLVMXCoreDesc
  LLVMXCoreDisassembler
  LLVMXCoreInfo
  LLVMipo)

set(HYLO_LLVM_DISTRIBUTION_SUPPORT
  llvm-headers
  cmake-exports
  lld-cmake-exports)

# get-llvm and make-pkgconfig.sh use llvm-config.
set(HYLO_LLVM_DISTRIBUTION_TOOLS
  lld
  llvm-config)
