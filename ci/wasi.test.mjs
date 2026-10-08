import assert from 'node:assert/strict'
import { test } from 'node:test'
import { libcxxTag, pkgConfig, sdkPaths, withThreads } from './wasi.mjs'

test('sdkPaths reads swift sdk configure output', () => {
  const output = 'sdkRootPath: /sdk/WASI.sdk\nswiftStaticResourcesPath: /sdk/lib/swift_static\n'
  assert.deepEqual(sdkPaths(output), { sysroot: '/sdk/WASI.sdk', resourceDir: '/sdk/lib/swift_static/clang' })
  assert.throws(() => sdkPaths('Error: no such SDK'))
})

test('libcxxTag reads _LIBCPP_VERSION', () => {
  assert.equal(libcxxTag('#  define _LIBCPP_VERSION 210106\n'), 'llvmorg-21.1.6')
})

test('withThreads enables threads over pthreads', () => {
  const site = '#define _LIBCPP_HAS_THREADS 0\n#define _LIBCPP_HAS_THREAD_API_PTHREAD 0\n'
  assert.equal(withThreads(site), '#define _LIBCPP_HAS_THREADS 1\n#define _LIBCPP_HAS_THREAD_API_PTHREAD 1\n')
  assert.throws(() => withThreads('#define _LIBCPP_HAS_THREADS 1\n'))
})

test('pkgConfig lists the static libraries and the libc++ headers', () => {
  const pc = pkgConfig('23.1.0', ['liblldWasm.a', 'libLLVMCore.a', 'libc++threads.a', 'cmake'])
  assert.match(pc, /^Libs: -L\$\{pcfiledir\}\/\.\.\/lib -lLLVMCore -lc\+\+threads -llldWasm$/m)
  assert.match(pc, /^Cflags: -I\$\{pcfiledir\}\/\.\.\/include -I\$\{pcfiledir\}\/\.\.\/libcxx-threads$/m)
})
