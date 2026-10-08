// Builds LLVM (WebAssembly target only) and lld's wasm port to run in WebAssembly, with the Swift
// toolchain's clang against the Swift wasm SDK, and installs them to --prefix together with a
// relocatable pkgconfig/llvm.pc.
//
// The SDK's libc++ is built without threads, but LLVM uses std::mutex and friends even with
// LLVM_ENABLE_THREADS=OFF. So LLVM is compiled with a __config_site that enables threads on top of
// wasi-libc's pthread stubs, and the parts of libc++ that this needs are built into
// lib/libc++threads.a. llvm.pc puts the __config_site on the consumer's include path too.
// The WASI SDK now does this itself (https://github.com/WebAssembly/wasi-libc/issues/501); once the
// Swift SDK does too, this can go.
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
import { libcxxTag, libcxxThreadSources, pkgConfig, sdkPaths, targets, triple, withThreads } from './wasi.mjs'

const options = parseOptions()
const toolchain = locateToolchain(options.sdk)
const threads = buildLibcxxThreads(toolchain, path.join(options.build, 'libcxx-threads'))
const env = {
  ...process.env,
  SWIFT_BIN: toolchain.bin,
  WASI_SYSROOT: toolchain.sysroot,
  WASI_RESOURCE_DIR: toolchain.resourceDir,
  LIBCXX_THREADS_INCLUDE: threads,
}
const llvm = buildLlvm(options, env)
installPackage(llvm, threads, options.prefix, env)

function parseOptions() {
  const names = ['sdk', 'source', 'native-tools', 'build', 'prefix']
  const { values } = parseArgs({ options: Object.fromEntries(names.map((n) => [n, { type: 'string' }])) })
  for (const name of names) {
    if (!values[name]) throw new Error(`Missing --${name}`)
  }
  for (const name of ['source', 'native-tools', 'build', 'prefix']) {
    values[name] = path.resolve(values[name])
  }
  return values
}

function run(command, args, options) {
  execFileSync(command, args, { stdio: 'inherit', ...options })
}

function output(command, args) {
  return execFileSync(command, args, { encoding: 'utf8' })
}

/** Returns the Swift toolchain's bin directory, and the SDK's sysroot and clang resource directory. */
function locateToolchain(sdk) {
  const bin = path.dirname(fs.realpathSync(output('which', ['swift']).trim()))
  return { bin, ...sdkPaths(output('swift', ['sdk', 'configure', '--show-configuration', sdk, triple])) }
}

/** Builds __config_site and libc++threads.a into `directory`, and returns it. */
function buildLibcxxThreads(toolchain, directory) {
  const headers = `${toolchain.sysroot}/include/c++/v1`
  const source = path.join(directory, 'source')
  fs.rmSync(directory, { recursive: true, force: true })
  run('git', ['-c', 'advice.detachedHead=false', 'clone', '--quiet', '--depth=1', '--filter=blob:none',
    '--sparse', '--branch', libcxxTag(fs.readFileSync(`${headers}/__config`, 'utf8')),
    'https://github.com/llvm/llvm-project.git', source])
  run('git', ['-C', source, 'sparse-checkout', 'set', 'libcxx'])

  fs.writeFileSync(path.join(directory, '__config_site'),
    withThreads(fs.readFileSync(`${headers}/__config_site`, 'utf8')))
  const objects = libcxxThreadSources.map((name) => {
    const object = path.join(directory, `${name}.o`)
    run(`${toolchain.bin}/clang++`, [`--target=${triple}`, `--sysroot=${toolchain.sysroot}`,
      `-resource-dir=${toolchain.resourceDir}`, '-isystem', directory, '-std=c++23', '-Os',
      '-fno-exceptions', '-DNDEBUG', '-D_LIBCPP_BUILDING_LIBRARY', `-I${source}/libcxx/src`,
      '-c', `${source}/libcxx/src/${name}.cpp`, '-o', object])
    return object
  })
  run(`${toolchain.bin}/llvm-ar`, ['rcs', path.join(directory, 'libc++threads.a'), ...objects])
  return directory
}

/** Configures and builds LLVM, and returns the build directory. */
function buildLlvm(options, env) {
  const directory = path.join(options.build, 'llvm')
  run('cmake', ['-G', 'Ninja', '-S', path.join(options.source, 'llvm'), '-B', directory,
    '-C', fileURLToPath(new URL('../cmake/caches/LLVM-wasi.cmake', import.meta.url)),
    `-DLLVM_NATIVE_TOOL_DIR=${options['native-tools']}`,
    `-DCMAKE_INSTALL_PREFIX=${options.prefix}`], { env })
  run('cmake', ['--build', directory, '--target', ...targets], { env })
  return directory
}

/** Installs the headers, libraries, __config_site and llvm.pc into `prefix`. */
function installPackage(llvm, threads, prefix, env) {
  fs.rmSync(prefix, { recursive: true, force: true })
  run('cmake', ['--build', llvm, '--target', 'install-llvm-headers', 'install-lld-headers'], { env })

  fs.mkdirSync(path.join(prefix, 'lib'))
  for (const file of fs.readdirSync(path.join(llvm, 'lib')).filter((f) => f.endsWith('.a'))) {
    fs.copyFileSync(path.join(llvm, 'lib', file), path.join(prefix, 'lib', file))
  }
  fs.copyFileSync(path.join(threads, 'libc++threads.a'), path.join(prefix, 'lib', 'libc++threads.a'))
  fs.mkdirSync(path.join(prefix, 'libcxx-threads'))
  fs.copyFileSync(path.join(threads, '__config_site'), path.join(prefix, 'libcxx-threads', '__config_site'))

  const config = fs.readFileSync(path.join(prefix, 'include/llvm/Config/llvm-config.h'), 'utf8')
  const version = config.match(/^#define LLVM_VERSION_STRING "(.+)"$/m)[1]
  const pc = pkgConfig(version, fs.readdirSync(path.join(prefix, 'lib')))
  fs.mkdirSync(path.join(prefix, 'pkgconfig'))
  fs.writeFileSync(path.join(prefix, 'pkgconfig', 'llvm.pc'), pc)
  console.log(pc)
}
