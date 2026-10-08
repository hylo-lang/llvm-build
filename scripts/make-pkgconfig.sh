#!/usr/bin/env bash

# Writes a relocatable pkg-config file (llvm.pc) for the LLVM whose llvm-config is first on PATH.
# The file has to be one directory below the LLVM prefix, e.g. <prefix>/pkgconfig/llvm.pc.
#
# Usage: make-pkgconfig.sh <path-to-pc-file>

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <path-to-pc-file>" >&2
    exit 1
fi
command -v llvm-config > /dev/null || { echo "Error: llvm-config is not on PATH" >&2; exit 1; }

# Prints the arguments with slashes for backslashes, whitespace collapsed, and the LLVM prefix
# replaced by ${pcfiledir}/..
relocatable() {
    local prefix
    prefix=$(llvm-config --prefix | sed 's|\\|/|g')
    echo "$*" | sed 's|\\|/|g' | tr -s '[:space:]' ' ' |
        sed -e "s|${prefix%/}/|\${pcfiledir}/../|g" -e 's/^ //' -e 's/ $//'
}

libs=$(relocatable "-L$(llvm-config --libdir)" \
    "$(llvm-config --system-libs --libs core analysis bitwriter passes target all-targets)")

# On Windows, llvm-config lists libraries as .lib paths and names, but SwiftPM needs -l flags.
# See https://github.com/hylo-lang/llvm-build/pull/36
case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) libs=$(echo "$libs" | sed -E 's#([^ ]*/)?([^ /]+)\.lib#-l\2#g') ;;
esac

# SwiftPM only accepts -I flags from pkg-config, so --cxxflags isn't used.
mkdir -p "$(dirname "$1")"
cat > "$1" <<END
Name: LLVM
Description: Low-level Virtual Machine compiler framework
Version: $(llvm-config --version | sed -E 's/^([0-9.]+).*/\1/')
URL: http://www.llvm.org/
Libs: $libs
Cflags: $(relocatable "-I$(llvm-config --includedir)")
END
cat "$1"
