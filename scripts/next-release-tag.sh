#!/usr/bin/env bash

# Prints the next release tag for an LLVM version, llvm-<version>-<n>, given the existing tags on
# stdin, one per line (refs/tags/ prefixes are ignored).
#
# Usage Example:
#   git ls-remote --tags --refs origin | cut -f2 | ./next-release-tag.sh 23.1.0

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <llvm-version> < tags" >&2
    exit 1
fi

prefix="llvm-$1-"
last=0
while read -r tag; do
    n=${tag#refs/tags/}
    [[ $n == "$prefix"* ]] || continue
    n=${n#"$prefix"}
    if [[ $n =~ ^[0-9]+$ ]] && (( 10#$n > last )); then
        last=$((10#$n))
    fi
done
echo "$prefix$((last + 1))"
