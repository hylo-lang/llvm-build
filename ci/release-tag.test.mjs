import assert from 'node:assert/strict'
import { test } from 'node:test'
import { nextReleaseTag } from './release-tag.mjs'

test('nextReleaseTag counts up per LLVM version', () => {
  assert.equal(nextReleaseTag('23.1.0', []), 'llvm-23.1.0-1')

  const tags = ['refs/tags/llvm-23.1.0-9', 'llvm-23.1.0-10', 'llvm-23.1.01-50', '20260912-184248', '']
  assert.equal(nextReleaseTag('23.1.0', tags), 'llvm-23.1.0-11')
})
