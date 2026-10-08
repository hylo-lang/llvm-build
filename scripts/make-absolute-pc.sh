#!/usr/bin/env bash

# Prints the given .pc file with ${pcfiledir} replaced by the file's absolute directory.
#
# Usage: make-absolute-pc.sh <path-to-pc-file> > absolute.pc

set -euo pipefail

if [ $# -ne 1 ] || [ ! -f "$1" ]; then
    echo "Usage: $0 <path-to-pc-file>" >&2
    exit 1
fi

sed "s|\${pcfiledir}|$(cd "$(dirname "$1")" && pwd)|g" "$1"
