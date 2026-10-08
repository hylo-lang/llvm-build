#!/usr/bin/env bash

# Prints SWIFT_BIN, WASI_SYSROOT and WASI_RESOURCE_DIR for an installed Swift wasm SDK, as
# NAME=value lines.
#
# Usage: swift-wasm-sdk-env.sh <sdk-name>, e.g. swift-6.3.2-RELEASE_wasm

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <swift-sdk-name>" >&2
    exit 1
fi

swift=$(command -v swift) || { echo "Error: swift is not on PATH" >&2; exit 1; }
configuration=$(swift sdk configure --show-configuration "$1" wasm32-unknown-wasip1)

sysroot=$(sed -n 's/^sdkRootPath: //p' <<< "$configuration")
resources=$(sed -n 's/^swiftStaticResourcesPath: //p' <<< "$configuration")
if [ -z "$sysroot" ] || [ -z "$resources" ]; then
    echo "Error: unexpected output from swift sdk configure:" >&2
    echo "$configuration" >&2
    exit 1
fi

echo "SWIFT_BIN=$(dirname "$(readlink -f "$swift")")"
echo "WASI_SYSROOT=$sysroot"
echo "WASI_RESOURCE_DIR=$resources/clang"
