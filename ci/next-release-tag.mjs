// Prints the next release tag, llvm-<version>-<n>, given the existing tags on stdin.
//
//   git ls-remote --tags --refs origin | cut -f2 | node ci/next-release-tag.mjs 23.1.0

import fs from 'node:fs'
import { fileURLToPath } from 'node:url'

export function nextReleaseTag(version, tags) {
  const prefix = `llvm-${version}-`
  const numbers = tags
    .map((tag) => tag.replace(/^refs\/tags\//, ''))
    .filter((tag) => tag.startsWith(prefix) && /^\d+$/.test(tag.slice(prefix.length)))
    .map((tag) => Number(tag.slice(prefix.length)))
  return prefix + (Math.max(0, ...numbers) + 1)
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const version = process.argv[2]
  if (!version) throw new Error('usage: node ci/next-release-tag.mjs <llvm-version> < tags')
  console.log(nextReleaseTag(version, fs.readFileSync(0, 'utf8').split('\n')))
}
