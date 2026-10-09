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
//   node ci/build-llvm-wasi.ts --sdk swift-6.3.2-RELEASE_wasm --source <patched llvm-project> \
//     --native-tools <directory with llvm-tblgen and llvm-min-tblgen> --build <dir> --prefix <dir>
//
// Needs Node 24, swift (with the SDK installed), git, CMake 3.31 or later and ninja. Re-running with
// the same --build continues the previous build.

import { type ExecFileSyncOptions, execFileSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { parseArgs } from 'node:util'
import { type SdkPaths, libcxxTag, libcxxThreadSources, pkgConfig, sdkPaths, targets, triple, withThreads } from './wasi.ts'

/** The command-line options. All but `sdk` are absolute paths. */
interface Options {
  /** The name of the Swift wasm SDK, as `swift sdk list` shows it. */
  sdk: string
  /** The patched llvm-project checkout. */
  source: string
  /** The directory with native llvm-tblgen and llvm-min-tblgen. */
  nativeTools: string
  build: string
  prefix: string
}

/** The Swift toolchain and wasm SDK that LLVM is built with. */
interface Toolchain extends SdkPaths {
  /** The toolchain's bin directory, with clang++ and llvm-ar. */
  bin: string
}

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

/** Returns the command-line options, with the directories made absolute. Throws if one is missing. */
function parseOptions(): Options {
  const names = ['sdk', 'source', 'native-tools', 'build', 'prefix']
  const { values } = parseArgs({ options: Object.fromEntries(names.map((n) => [n, { type: 'string' }])) })
  const value = (name: string) => {
    const result = values[name]
    if (typeof result !== 'string' || !result) throw new Error(`Missing --${name}`)
    return result
  }
  return {
    sdk: value('sdk'),
    source: path.resolve(value('source')),
    nativeTools: path.resolve(value('native-tools')),
    build: path.resolve(value('build')),
    prefix: path.resolve(value('prefix')),
  }
}

/** Runs `command` with `args`, showing its output; `options` override execFileSync's. Throws if it fails. */
function run(command: string, args: string[], options?: ExecFileSyncOptions) {
  execFileSync(command, args, { stdio: 'inherit', ...options })
}

/** Returns what `command` with `args` prints to stdout. Throws if it fails. */
function output(command: string, args: string[]): string {
  return execFileSync(command, args, { encoding: 'utf8' })
}

/** Writes `contents` to `file` unless it already has them, so that the build doesn't see a change. */
function writeIfChanged(file: string, contents: string) {
  if (!fs.existsSync(file) || fs.readFileSync(file, 'utf8') !== contents) fs.writeFileSync(file, contents)
}

/**
 * Returns the Swift toolchain on PATH, with its installed wasm SDK `sdk`. Throws if swift isn't on
 * PATH, or `sdk` isn't installed.
 */
function locateToolchain(sdk: string): Toolchain {
  const bin = path.dirname(fs.realpathSync(output('which', ['swift']).trim()))
  return { bin, ...sdkPaths(output('swift', ['sdk', 'configure', '--show-configuration', sdk, triple])) }
}

/**
 * Builds a __config_site with threads enabled and libc++threads.a into `directory`, from the libc++
 * sources that match the SDK, and returns `directory`. The sources are cloned into `directory` the
 * first time. Throws if cloning or building fails.
 */
function buildLibcxxThreads(toolchain: Toolchain, directory: string): string {
  const headers = `${toolchain.sysroot}/include/c++/v1`
  const tag = libcxxTag(fs.readFileSync(`${headers}/__config`, 'utf8'))
  const source = path.join(directory, tag)
  if (!fs.existsSync(source)) {
    const clone = `${source}.partial`
    fs.rmSync(clone, { recursive: true, force: true })
    run('git', ['-c', 'advice.detachedHead=false', 'clone', '--quiet', '--depth=1', '--filter=blob:none',
      '--sparse', '--branch', tag, 'https://github.com/llvm/llvm-project.git', clone])
    run('git', ['-C', clone, 'sparse-checkout', 'set', 'libcxx'])
    fs.renameSync(clone, source)
  }

  // Every LLVM object includes __config_site, so rewriting it unchanged would rebuild all of LLVM.
  writeIfChanged(path.join(directory, '__config_site'),
    withThreads(fs.readFileSync(`${headers}/__config_site`, 'utf8')))
  const objects = libcxxThreadSources.map((name) => {
    const object = path.join(directory, `${name}.o`)
    run(`${toolchain.bin}/clang++`, [`--target=${triple}`, `--sysroot=${toolchain.sysroot}`,
      `-resource-dir=${toolchain.resourceDir}`, '-isystem', directory, '-std=c++23', '-Os',
      '-fno-exceptions', '-DNDEBUG', '-D_LIBCPP_BUILDING_LIBRARY', `-I${source}/libcxx/src`,
      '-c', `${source}/libcxx/src/${name}.cpp`, '-o', object])
    return object
  })
  const archive = path.join(directory, 'libc++threads.a')
  fs.rmSync(archive, { force: true })
  run(`${toolchain.bin}/llvm-ar`, ['rcs', archive, ...objects])
  return directory
}

/**
 * Configures LLVM from `options.source` in `options.build`/llvm to install into `options.prefix`, and
 * builds `targets` there. `env` has the variables cmake/wasi-toolchain.cmake needs. Returns the build
 * directory, and throws if configuring or building fails.
 */
function buildLlvm(options: Options, env: NodeJS.ProcessEnv): string {
  const directory = path.join(options.build, 'llvm')
  run('cmake', ['-G', 'Ninja', '-S', path.join(options.source, 'llvm'), '-B', directory,
    '-C', fileURLToPath(new URL('../cmake/caches/LLVM-wasi.cmake', import.meta.url)),
    `-DLLVM_NATIVE_TOOL_DIR=${options.nativeTools}`,
    `-DCMAKE_INSTALL_PREFIX=${options.prefix}`], { env })
  run('cmake', ['--build', directory, '--target', ...targets], { env })
  return directory
}

/**
 * Replaces `prefix` with the package: the LLVM and lld headers, every static library in `llvm`/lib,
 * the libc++threads.a and __config_site in `threads`, and an llvm.pc for them, which it also prints.
 * `llvm` must have been configured by buildLlvm with `prefix` and `env`, since CMake installs the
 * headers. Throws if installing fails.
 */
function installPackage(llvm: string, threads: string, prefix: string, env: NodeJS.ProcessEnv) {
  fs.rmSync(prefix, { recursive: true, force: true })
  run('cmake', ['--build', llvm, '--target', 'install-llvm-headers', 'install-lld-headers'], { env })

  fs.mkdirSync(path.join(prefix, 'lib'), { recursive: true })
  for (const file of fs.readdirSync(path.join(llvm, 'lib')).filter((f) => f.endsWith('.a'))) {
    fs.copyFileSync(path.join(llvm, 'lib', file), path.join(prefix, 'lib', file))
  }
  fs.copyFileSync(path.join(threads, 'libc++threads.a'), path.join(prefix, 'lib', 'libc++threads.a'))
  fs.mkdirSync(path.join(prefix, 'libcxx-threads'), { recursive: true })
  fs.copyFileSync(path.join(threads, '__config_site'), path.join(prefix, 'libcxx-threads', '__config_site'))

  const config = fs.readFileSync(path.join(prefix, 'include/llvm/Config/llvm-config.h'), 'utf8')
  const version = config.match(/^#define LLVM_VERSION_STRING "(.+)"$/m)?.[1]
  if (!version) throw new Error('No LLVM_VERSION_STRING in llvm-config.h')
  const pc = pkgConfig(version, fs.readdirSync(path.join(prefix, 'lib')))
  fs.mkdirSync(path.join(prefix, 'pkgconfig'), { recursive: true })
  fs.writeFileSync(path.join(prefix, 'pkgconfig', 'llvm.pc'), pc)
  console.log(pc)
}
