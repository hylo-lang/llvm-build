// Builds LLVM (WebAssembly target only) and lld's wasm port to run in WebAssembly, with the Swift
// toolchain's clang against the Swift wasm SDK, and installs them to --prefix together with a
// relocatable pkgconfig/llvm.pc.
//
// The SDK's libc++ is built without threads, but LLVM uses std::mutex and friends even with
// LLVM_ENABLE_THREADS=OFF. So LLVM is compiled with a __config_site that enables threads on top of
// wasi-libc's pthread stubs, and the parts of libc++ that this needs are built into
// lib/libc++threads.a. llvm.pc puts the __config_site on the consumer's include path too.
//
//   node ci/build-llvm-wasi.mjs --sdk swift-6.3.2-RELEASE_wasm --source <patched llvm-project> \
//     --native-tools <directory with llvm-tblgen and llvm-min-tblgen> --build <dir> --prefix <dir>
//
// Needs swift (with the SDK installed), git, CMake 3.31 or later and ninja.

import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { parseArgs } from 'node:util'

const triple = 'wasm32-unknown-wasip1'

// What Swifty-LLVM needs for the WebAssembly target, and lld for linking in-process.
const targets = [
  'LLVMCore', 'LLVMSupport', 'LLVMAnalysis', 'LLVMBitWriter', 'LLVMPasses', 'LLVMTarget',
  'LLVMTargetParser', 'LLVMWebAssemblyCodeGen', 'LLVMWebAssemblyAsmParser',
  'LLVMWebAssemblyDisassembler', 'LLVMWebAssemblyDesc', 'LLVMWebAssemblyInfo',
  'LLVMWebAssemblyUtils', 'lldWasm', 'lldCommon',
]

// The parts of libc++ that need to be compiled when threads are enabled.
const libcxxThreadSources = [
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

function main() {
  const names = ['sdk', 'source', 'native-tools', 'build', 'prefix']
  const { values } = parseArgs({ options: Object.fromEntries(names.map((n) => [n, { type: 'string' }])) })
  for (const n of names) if (!values[n]) throw new Error(`Missing --${n}`)

  const run = (command, args, options) => execFileSync(command, args, { stdio: 'inherit', ...options })
  const output = (command, args) => execFileSync(command, args, { encoding: 'utf8' })
  const build = path.resolve(values.build)
  const prefix = path.resolve(values.prefix)

  const swiftBin = path.dirname(fs.realpathSync(output('which', ['swift']).trim()))
  const sdk = sdkPaths(output('swift', ['sdk', 'configure', '--show-configuration', values.sdk, triple]))
  const libcxxHeaders = `${sdk.sysroot}/include/c++/v1`

  // libc++ thread support. __config_site is only rewritten when it changes, since everything
  // depends on it.
  const threads = path.join(build, 'libcxx-threads')
  const libcxx = path.join(build, 'libcxx-source')
  if (!fs.existsSync(libcxx)) {
    const tag = libcxxTag(fs.readFileSync(`${libcxxHeaders}/__config`, 'utf8'))
    run('git', ['-c', 'advice.detachedHead=false', 'clone', '--quiet', '--depth=1', '--filter=blob:none',
      '--sparse', '--branch', tag, 'https://github.com/llvm/llvm-project.git', libcxx])
    run('git', ['-C', libcxx, 'sparse-checkout', 'set', 'libcxx'])
  }
  fs.mkdirSync(threads, { recursive: true })
  const configSite = withThreads(fs.readFileSync(`${libcxxHeaders}/__config_site`, 'utf8'))
  const configSitePath = path.join(threads, '__config_site')
  if (!fs.existsSync(configSitePath) || fs.readFileSync(configSitePath, 'utf8') !== configSite) {
    fs.writeFileSync(configSitePath, configSite)
  }
  const objects = libcxxThreadSources.map((name) => {
    const object = path.join(threads, `${name}.o`)
    run(`${swiftBin}/clang++`, [`--target=${triple}`, `--sysroot=${sdk.sysroot}`,
      `-resource-dir=${sdk.resourceDir}`, '-isystem', threads, '-std=c++23', '-Os', '-fno-exceptions',
      '-DNDEBUG', '-D_LIBCPP_BUILDING_LIBRARY', `-I${libcxx}/libcxx/src`,
      '-c', `${libcxx}/libcxx/src/${name}.cpp`, '-o', object])
    return object
  })
  fs.rmSync(path.join(threads, 'libc++threads.a'), { force: true })
  run(`${swiftBin}/llvm-ar`, ['rcs', path.join(threads, 'libc++threads.a'), ...objects])

  // LLVM. The toolchain file reads the toolchain's locations from the environment.
  const env = {
    ...process.env,
    SWIFT_BIN: swiftBin,
    WASI_SYSROOT: sdk.sysroot,
    WASI_RESOURCE_DIR: sdk.resourceDir,
    LIBCXX_THREADS_INCLUDE: threads,
  }
  const llvm = path.join(build, 'llvm')
  run('cmake', ['-G', 'Ninja', '-S', path.join(values.source, 'llvm'), '-B', llvm,
    '-C', fileURLToPath(new URL('../cmake/caches/LLVM-wasi.cmake', import.meta.url)),
    `-DLLVM_NATIVE_TOOL_DIR=${path.resolve(values['native-tools'])}`,
    `-DCMAKE_INSTALL_PREFIX=${prefix}`], { env })
  run('cmake', ['--build', llvm, '--target', ...targets], { env })

  // The package.
  fs.rmSync(prefix, { recursive: true, force: true })
  run('cmake', ['--build', llvm, '--target', 'install-llvm-headers', 'install-lld-headers'], { env })
  for (const directory of ['lib', 'libcxx-threads', 'pkgconfig']) {
    fs.mkdirSync(path.join(prefix, directory), { recursive: true })
  }
  for (const file of fs.readdirSync(path.join(llvm, 'lib')).filter((f) => f.endsWith('.a'))) {
    fs.copyFileSync(path.join(llvm, 'lib', file), path.join(prefix, 'lib', file))
  }
  fs.copyFileSync(path.join(threads, 'libc++threads.a'), path.join(prefix, 'lib', 'libc++threads.a'))
  fs.copyFileSync(configSitePath, path.join(prefix, 'libcxx-threads', '__config_site'))
  const config = fs.readFileSync(path.join(prefix, 'include/llvm/Config/llvm-config.h'), 'utf8')
  const version = config.match(/^#define LLVM_VERSION_STRING "(.+)"$/m)[1]
  const pc = pkgConfig(version, fs.readdirSync(path.join(prefix, 'lib')))
  fs.writeFileSync(path.join(prefix, 'pkgconfig', 'llvm.pc'), pc)
  console.log(pc)
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main()
} 
