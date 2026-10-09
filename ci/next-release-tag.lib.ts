/**
 * Returns the next release tag for LLVM `version` (e.g. 23.1.0), llvm-<version>-<n>, where n is one
 * more than the highest among the existing `tags`, or 1 if there is none. Tags may start with
 * refs/tags/, and ones that aren't release tags of `version` are ignored.
 */
export function nextReleaseTag(version: string, tags: string[]): string {
  const prefix = `llvm-${version}-`
  const numbers = tags
    .map((tag) => tag.replace(/^refs\/tags\//, ''))
    .filter((tag) => tag.startsWith(prefix) && /^\d+$/.test(tag.slice(prefix.length)))
    .map((tag) => Number(tag.slice(prefix.length)))
  return prefix + (Math.max(0, ...numbers) + 1)
}
