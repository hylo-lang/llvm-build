// What build-llvm-wasi.mjs needs to know about LLVM, libc++ and the Swift wasm SDK.

export const triple = 'wasm32-unknown-wasip1'

// What Swifty-LLVM needs for the WebAssembly target, and lld for linking in-process.
export const targets = [
  'LLVMCore', 'LLVMSupport', 'LLVMAnalysis', 'LLVMBitWriter', 'LLVMPasses', 'LLVMTarget',
  'LLVMTargetParser', 'LLVMWebAssemblyCodeGen', 'LLVMWebAssemblyAsmParser',
  'LLVMWebAssemblyDisassembler', 'LLVMWebAssemblyDesc', 'LLVMWebAssemblyInfo',
  'LLVMWebAssemblyUtils', 'lldWasm', 'lldCommon',
]

// The parts of libc++ that need to be compiled when threads are enabled.
export const libcxxThreadSources = [
  'mutex', 'mutex_destructor', 'condition_variable', 'condition_variable_destructor', 'future',
  'shared_mutex', 'thread', 'atomic', 'barrier',
]

/** Returns the sysroot and clang resource directory from `swift sdk configure --show-configuration`. */
export function sdkPaths(configuration) {
  const field = (name) => configuration.match(new RegExp(`^${name}: (.+)$`, 'm'))?.[1]
  const sysroot = field('sdkRootPath')
  const resources = field('swiftStaticResourcesPath')
  if (!sysroot || !resources) throw new Error(`Unexpected SDK configuration:\n${configuration}`)
  return { sysroot, resourceDir: `${resources}/clang` }
}

/** Returns the llvm-project tag of the libc++ whose __config is given. */
export function libcxxTag(config) {
  const version = Number(config.match(/^#\s*define _LIBCPP_VERSION (\d+)$/m)?.[1])
  if (!version) throw new Error('No _LIBCPP_VERSION in __config')
  return `llvmorg-${Math.floor(version / 10000)}.${Math.floor(version / 100) % 100}.${version % 100}`
}

/** Returns the given __config_site with threads enabled on top of pthreads. */
export function withThreads(configSite) {
  let result = configSite
  for (const name of ['_LIBCPP_HAS_THREADS', '_LIBCPP_HAS_THREAD_API_PTHREAD']) {
    if (!result.includes(`#define ${name} 0`)) throw new Error(`No "#define ${name} 0" in __config_site`)
    result = result.replace(`#define ${name} 0`, `#define ${name} 1`)
  }
  return result
}

/** Returns a relocatable llvm.pc that links the static libraries among the given file names. */
export function pkgConfig(version, files) {
  const libs = files.filter((f) => /^lib.+\.a$/.test(f)).sort().map((f) => `-l${f.slice(3, -2)}`)
  return [
    'Name: LLVM',
    'Description: Low-level Virtual Machine compiler framework',
    `Version: ${version}`,
    'URL: http://www.llvm.org/',
    `Libs: -L\${pcfiledir}/../lib ${libs.join(' ')}`,
    'Cflags: -I${pcfiledir}/../include -I${pcfiledir}/../libcxx-threads',
    '',
  ].join('\n')
}
