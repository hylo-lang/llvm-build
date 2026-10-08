#!/usr/bin/env bash

# Tests the scripts against the fake llvm-config in tests/stub-llvm, installed to a path with a
# space in it.

set -euo pipefail

repository="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

prefix="$work/llvm install"
cp -R "$repository/tests/stub-llvm" "$prefix"
cp "$repository/scripts/install-pc.sh" "$repository/scripts/make-absolute-pc.sh" "$prefix/"
mkdir -p "$prefix/pkgconfig"
cp "$prefix"/*.sh "$prefix/pkgconfig/"

failures=0

# expect_equal <description> <actual> <expected>
expect_equal() {
  if [ "$2" != "$3" ]; then
    echo "FAIL: $1" >&2
    echo "  expected: $3" >&2
    echo "  actual:   $2" >&2
    failures=$((failures + 1))
  else
    echo "ok: $1"
  fi
}

PATH="$prefix/bin:$PATH" "$repository/scripts/make-pkgconfig.sh" "$prefix/pkgconfig/llvm.pc" > /dev/null
pc="$prefix/pkgconfig/llvm.pc"

expect_equal "Version is trimmed to digits" \
  "$(grep '^Version:' "$pc")" "Version: 23.1.0"
expect_equal "Libs are relocatable with collapsed whitespace" \
  "$(grep '^Libs:' "$pc")" 'Libs: -L${pcfiledir}/../lib -lLLVMCore -lLLVMSupport -lrt -ldl -lm'
expect_equal "Cflags hold only the include directory" \
  "$(grep '^Cflags:' "$pc")" 'Cflags: -I${pcfiledir}/../include'

absolute=$("$prefix/pkgconfig/make-absolute-pc.sh" "$pc")
expect_equal "make-absolute-pc.sh resolves \${pcfiledir}" \
  "$(echo "$absolute" | grep '^Cflags:')" "Cflags: -I$prefix/pkgconfig/../include"

"$prefix/pkgconfig/install-pc.sh" "$pc" "$work/destination" > /dev/null
expect_equal "install-pc.sh installs the absolute file" \
  "$(cat "$work/destination/llvm.pc")" "$absolute"

if "$prefix/pkgconfig/install-pc.sh" "$work/missing.pc" "$work/destination" 2> /dev/null; then
  expect_equal "install-pc.sh fails on a missing file" "succeeded" "failed"
else
  expect_equal "install-pc.sh fails on a missing file" "failed" "failed"
fi

if [ "$failures" -ne 0 ]; then
  echo "$failures test(s) failed" >&2
  exit 1
fi
