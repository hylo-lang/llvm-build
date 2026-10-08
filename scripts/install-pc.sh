#!/usr/bin/env bash

# Installs the given .pc file into a pkg-config search directory (by default
# /usr/local/lib/pkgconfig). The installed copy has absolute paths, since it no longer lives next
# to LLVM.
#
# Usage: install-pc.sh <path-to-pc-file> [destination-directory]

set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ] || [ ! -f "$1" ]; then
    echo "Usage: $0 <path-to-pc-file> [destination-directory]" >&2
    exit 1
fi

destination=${2:-/usr/local/lib/pkgconfig}
mkdir -p "$destination"
"$(dirname "$0")/make-absolute-pc.sh" "$1" > "$destination/$(basename "$1")"
echo "Installed $destination/$(basename "$1")"
