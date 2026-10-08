// Prints the next release tag, llvm-<version>-<n>, given the existing tags on stdin.
//
//   git ls-remote --tags --refs origin | cut -f2 | node ci/next-release-tag.mjs 23.1.0

import fs from 'node:fs'
import { nextReleaseTag } from './release-tag.mjs'

const version = process.argv[2]
if (!version) throw new Error('Usage: node ci/next-release-tag.mjs <llvm-version> < tags')
console.log(nextReleaseTag(version, fs.readFileSync(0, 'utf8').split('\n')))
