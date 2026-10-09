// Prints the next release tag, llvm-<version>-<n>, given the existing tags on stdin.
//
//   git ls-remote --tags --refs origin | cut -f2 | node ci/next-release-tag.ts 23.1.0

import fs from 'node:fs'
import { nextReleaseTag } from './next-release-tag.lib.ts'

const version = process.argv[2]
if (!version) {
  throw new Error('Usage: node ci/next-release-tag.ts <llvm-version> < tags')
}
console.log(nextReleaseTag(version, fs.readFileSync(0, 'utf8').split('\n')))
