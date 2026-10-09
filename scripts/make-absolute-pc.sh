#!/usr/bin/env bash

# Prints the given .pc file with ${pcfiledir} replaced by the file's absolute directory.
#
# Usage: make-absolute-pc.sh <path-to-pc-file> > absolute.pc

set -euo pipefail

if [ $# -ne 1 ] || [ ! -f "$1" ]; then
    echo "Usage: $0 <path-to-pc-file>" >&2
    exit 1
fi

# The file's directory, as given, e.g. pkgconfig.
pcfiledir=$(dirname -- "$1")
# Made absolute without resolving symlinks.
pcfiledir=$(CDPATH='' cd -- "$pcfiledir" && pwd)
# Escaped for the sed replacement, where \, & and the | delimiter are special.
pcfiledir=$(printf '%s\n' "$pcfiledir" | sed 's/[\\&|]/\\&/g')
sed "s|\${pcfiledir}|$pcfiledir|g" "$1"
