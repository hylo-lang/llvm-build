// Tests the distributed pkg-config scripts in scripts/ against a fake LLVM installation.

import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { test } from 'node:test'
import { fileURLToPath } from 'node:url'

const scripts = fileURLToPath(new URL('../scripts', import.meta.url))

/** Writes an executable shell script `name` to the existing directory `bin`, with `body` after the #! line. */
function writeScript(bin: string, name: string, body: string) {
  fs.writeFileSync(path.join(bin, name), `#!/bin/sh\n${body}`, { mode: 0o755 })
}

/**
 * Writes to the existing directory `bin` a fake llvm-config for LLVM 23.1.0git installed at
 * `prefix`, which prints `libs` for the libraries make-pkgconfig.sh asks for, and fails for any other
 * arguments. `prefix` and `libs` can't contain single quotes.
 */
function fakeLlvmConfig(bin: string, prefix: string, libs: string) {
  const responses = {
    '--version': '23.1.0git',
    '--prefix': prefix,
    '--libdir': `${prefix}/lib`,
    '--includedir': `${prefix}/include`,
    '--system-libs --libs core analysis bitwriter passes target all-targets': libs,
  }
  const cases = Object.entries(responses).map(([k, v]) => `'${k}') printf '%s\\n' '${v}' ;;`)
  writeScript(bin, 'llvm-config', `case "$*" in\n${cases.join('\n')}\n*) exit 1 ;;\nesac\n`)
}

/** Writes to the existing directory `bin` a fake uname that prints `system`, which can't contain shell syntax. */
function fakeUname(bin: string, system: string) {
  writeScript(bin, 'uname', `echo ${system}\n`)
}

/** The fake LLVM installation that makePkgconfig runs make-pkgconfig.sh for. */
interface Fake {
  /** What llvm-config prints for the libraries of the LLVM installed at `prefix`. */
  libs: (prefix: string) => string
  /** What uname prints; Linux by default. */
  system?: string
}

/**
 * Runs make-pkgconfig.sh for `fake` in a new directory, whose path has a space in it, and returns
 * the path of the llvm.pc it writes. Throws if make-pkgconfig.sh fails.
 */
function makePkgconfig({ libs, system = 'Linux' }: Fake): string {
  const prefix = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'llvm-')), 'llvm install')
  const bin = path.join(prefix, 'bin')
  fs.mkdirSync(bin, { recursive: true })
  fakeLlvmConfig(bin, prefix, libs(prefix))
  fakeUname(bin, system)

  const pc = path.join(prefix, 'pkgconfig', 'llvm.pc')
  execFileSync('bash', [path.join(scripts, 'make-pkgconfig.sh'), pc], {
    env: { ...process.env, PATH: bin + path.delimiter + process.env.PATH },
  })
  return pc
}

/** Returns the value of the field `name` in the .pc file at `pc`. Throws if there is no such field. */
function field(pc: string, name: string): string {
  const value = fs.readFileSync(pc, 'utf8').match(new RegExp(`^${name}: (.*)$`, 'm'))?.[1]
  if (value === undefined) throw new Error(`No ${name} in ${pc}`)
  return value
}

test('llvm.pc is relocatable, with only -I in Cflags', () => {
  const pc = makePkgconfig({ libs: () => '-lLLVMCore  -lLLVMSupport\n-lrt -lm' })
  assert.equal(field(pc, 'Version'), '23.1.0')
  assert.equal(field(pc, 'Libs'), '-L${pcfiledir}/../lib -lLLVMCore -lLLVMSupport -lrt -lm')
  assert.equal(field(pc, 'Cflags'), '-I${pcfiledir}/../include')
})

test('on Windows, .lib paths and names become -l flags', () => {
  const pc = makePkgconfig({
    system: 'MINGW64_NT-10.0',
    libs: (prefix) => `${prefix}\\lib\\LLVMCore.lib ${prefix}\\lib\\LLVMSupport.lib\npsapi.lib`,
  })
  assert.equal(field(pc, 'Libs'), '-L${pcfiledir}/../lib -lLLVMCore -lLLVMSupport -lpsapi')
})

test('install-pc.sh installs a copy with absolute paths', () => {
  const pc = makePkgconfig({ libs: () => '-lLLVMCore' })
  const destination = fs.mkdtempSync(path.join(os.tmpdir(), 'pkgconfig-'))
  execFileSync('bash', [path.join(scripts, 'install-pc.sh'), pc, destination])
  const installed = path.join(destination, 'llvm.pc')
  assert.match(field(installed, 'Cflags'), /^-I\S.*\/llvm install\/pkgconfig\/\.\.\/include$/)
  assert.doesNotMatch(fs.readFileSync(installed, 'utf8'), /pcfiledir/)
})
