// What build-llvm-wasi.ts needs to know about LLVM, libc++ and the Swift wasm SDK.

/** The target triple that LLVM is built for, and runs on. */
export const triple = 'wasm32-unknown-wasip1'

/**
 * The CMake targets to build: what Swifty-LLVM needs for the WebAssembly target, and lld for linking
 * in-process.
 */
export const targets = [
  'LLVMCore', 'LLVMSupport', 'LLVMAnalysis', 'LLVMBitWriter', 'LLVMPasses', 'LLVMTarget',
  'LLVMTargetParser', 'LLVMWebAssemblyCodeGen', 'LLVMWebAssemblyAsmParser',
  'LLVMWebAssemblyDisassembler', 'LLVMWebAssemblyDesc', 'LLVMWebAssemblyInfo',
  'LLVMWebAssemblyUtils', 'lldWasm', 'lldCommon',
]

/** The libc++ sources, without libcxx/src/ and .cpp, that need to be compiled when threads are enabled. */
export const libcxxThreadSources = [
  'mutex', 'mutex_destructor', 'condition_variable', 'condition_variable_destructor', 'future',
  'shared_mutex', 'thread', 'atomic', 'barrier',
]

/** Where a Swift SDK keeps the files clang needs. */
export interface SdkPaths {
  sysroot: string
  /** The clang resource directory. */
  resourceDir: string
}

/**
 * Returns the paths of a Swift SDK, given what `swift sdk configure --show-configuration` prints for
 * it. Throws if either is missing.
 */
export function sdkPaths(configuration: string): SdkPaths {
  const field = (name: string) => configuration.match(new RegExp(`^${name}: (.+)$`, 'm'))?.[1]
  const sysroot = field('sdkRootPath')
  const resources = field('swiftStaticResourcesPath')
  if (!sysroot || !resources) throw new Error(`Unexpected SDK configuration:\n${configuration}`)
  return { sysroot, resourceDir: `${resources}/clang` }
}

/**
 * Returns the llvm-project tag, llvmorg-<major>.<minor>.<patch>, of the libc++ whose __config has the
 * contents `config`. Throws if it doesn't define _LIBCPP_VERSION.
 */
export function libcxxTag(config: string): string {
  const version = Number(config.match(/^#\s*define _LIBCPP_VERSION (\d+)$/m)?.[1])
  if (!version) throw new Error('No _LIBCPP_VERSION in __config')
  return `llvmorg-${Math.floor(version / 10000)}.${Math.floor(version / 100) % 100}.${version % 100}`
}

/**
 * Returns the contents of a __config_site with threads enabled on top of pthreads. Throws if it
 * doesn't define both _LIBCPP_HAS_THREADS and _LIBCPP_HAS_THREAD_API_PTHREAD to 0.
 */
export function withThreads(configSite: string): string {
  let result = configSite
  for (const name of ['_LIBCPP_HAS_THREADS', '_LIBCPP_HAS_THREAD_API_PTHREAD']) {
    if (!result.includes(`#define ${name} 0`)) throw new Error(`No "#define ${name} 0" in __config_site`)
    result = result.replace(`#define ${name} 0`, `#define ${name} 1`)
  }
  return result
}

/**
 * Returns a relocatable llvm.pc for LLVM `version`, in a package whose lib/ holds the files named
 * `files`. It links every lib*.a among them, and puts include/ and libcxx-threads/ on the include path.
 */
export function pkgConfig(version: string, files: string[]): string {
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
