// Tests the distributed pkg-config scripts in scripts/ against a fake LLVM installation.

import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { test } from 'node:test'
import { fileURLToPath } from 'node:url'

const scripts = fileURLToPath(new URL('../scripts', import.meta.url))

/** Runs make-pkgconfig.sh for a fake LLVM printing `libs`, on `system`, and returns llvm.pc. */
function makePkgconfig({ libs, system = 'Linux' }) {
  const prefix = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'llvm-')), 'llvm install')
  const bin = path.join(prefix, 'bin')
  fs.mkdirSync(bin, { recursive: true })
  const responses = {
    '--version': '23.1.0git',
    '--prefix': prefix,
    '--libdir': `${prefix}/lib`,
    '--includedir': `${prefix}/include`,
    '--system-libs --libs core analysis bitwriter passes target all-targets': libs(prefix),
  }
  const cases = Object.entries(responses).map(([k, v]) => `'${k}') printf '%s\\n' '${v}' ;;`)
  fs.writeFileSync(path.join(bin, 'llvm-config'),
    `#!/bin/sh\ncase "$*" in\n${cases.join('\n')}\n*) exit 1 ;;\nesac\n`, { mode: 0o755 })
  fs.writeFileSync(path.join(bin, 'uname'), `#!/bin/sh\necho ${system}\n`, { mode: 0o755 })

  const pc = path.join(prefix, 'pkgconfig', 'llvm.pc')
  execFileSync('bash', [path.join(scripts, 'make-pkgconfig.sh'), pc], {
    env: { ...process.env, PATH: bin + path.delimiter + process.env.PATH },
  })
  return pc
}

const field = (pc, name) => fs.readFileSync(pc, 'utf8').match(new RegExp(`^${name}: (.*)$`, 'm'))[1]

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
