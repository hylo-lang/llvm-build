/** Returns the next release tag, llvm-<version>-<n>, given the existing tags. */
export function nextReleaseTag(version, tags) {
  const prefix = `llvm-${version}-`
  const numbers = tags
    .map((tag) => tag.replace(/^refs\/tags\//, ''))
    .filter((tag) => tag.startsWith(prefix) && /^\d+$/.test(tag.slice(prefix.length)))
    .map((tag) => Number(tag.slice(prefix.length)))
  return prefix + (Math.max(0, ...numbers) + 1)
}
