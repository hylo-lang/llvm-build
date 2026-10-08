#!/usr/bin/env bash

# Generates a relocatable pkg-config file (llvm.pc) describing the LLVM build that the
# `llvm-config` first found on PATH belongs to, and writes it to the given path.
#
# The set of LLVM components written into "Libs:" is hardcoded below; edit the `llvm-config
# --libs` invocation if you need a different set. On Windows (MSYS/MinGW/Cygwin shells) the
# ".lib" paths and bare ".lib" names that llvm-config emits are rewritten into -l flags, which
# is what SwiftPM expects; see https://github.com/hylo-lang/llvm-build/pull/36
#
# With --installed-libraries, llvm-config isn't used (for a cross-compiled LLVM, it can't run).
# "Libs:" then lists every lib*.a in the lib directory, in no particular order, and the extra
# include directories, relative to the prefix, are added to "Cflags:".
#
# Parameters:
#   $1 - The path of the .pc file to write. Parent directories are created as needed.
#
# Requires:
#   - $1 must be in one directory below the LLVM installation prefix.
#
# Usage Examples:
#   export PATH="/path/to/llvm/bin:$PATH"
#   ./make-pkgconfig.sh "$(llvm-config --prefix)/pkgconfig/llvm.pc"
#   ./make-pkgconfig.sh --installed-libraries 23.1.0 /path/to/llvm/pkgconfig/llvm.pc libcxx-threads

set -euo pipefail

usage() {
    echo "Usage: $0 <path-to-pc-file>" >&2
    echo "       $0 --installed-libraries <version> <path-to-pc-file> [<include-dir>...]" >&2
    exit 1
}

if [ "${1:-}" = --installed-libraries ]; then
    [ $# -ge 3 ] || usage
    from_installed_libraries=true
    version=$2
    filename=$3
    shift 3
    extra_include_dirs=("$@")
else
    [ $# -eq 1 ] || usage
    from_installed_libraries=false
    filename=$1

    if ! command -v llvm-config > /dev/null 2>&1; then
        echo "Error: 'llvm-config' was not found on PATH" >&2
        exit 1
    fi
    version=$(llvm-config --version)
fi

mkdir -p "$(dirname "$filename")"
touch "$filename"

# Outputs $1 with normalized path separators.
#
# Replaces backslashes with forward slashes.
normalize_path_separators() {
    echo "$1" | sed 's/\\/\//g'
}

# Outputs $1 with absolute paths replaced by relocatable paths.
#
# Occurrences of the package prefix are replaced by "${pcfiledir}/../".
replace_with_relocatable_paths() {
    local input llvm_root
    input=$(normalize_path_separators "$1")
    llvm_root=$(normalize_path_separators "$(llvm-config --prefix)")
    
    # Ensure llvm_root ends with a separator
    if [[ ! "$llvm_root" =~ /$ ]]; then
        llvm_root="${llvm_root}/"
    fi
    
    # Replace absolute LLVM root path with relocatable path
    echo "$input" | sed "s|${llvm_root}|\${pcfiledir}/../|g"
}

# Outputs $1 with all contiguous white-space subsequences replaced by a single space,
# trimming at start and end.
normalize_spaces() {
    echo "$1" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

# Outputs $1 with any MSVC-style library paths replaced with -l flags if the script is run on Windows.
#
# On Windows, llvm-config --libs outputs full paths (e.g. C:\path\LLVMCore.lib) and --system-libs
# outputs bare file names (e.g. psapi.lib). Convert both to -l flags for SPM compatibility.
#
# Requires: $1 doesn't contain any spaces.
#
# See https://github.com/hylo-lang/llvm-build/pull/36
convert_libs_to_spm_compatible_flags() {
    local operating_system
    operating_system="$(uname -s)"
    if [[ "$operating_system" == MINGW* || "$operating_system" == MSYS* || "$operating_system" == CYGWIN* ]]; then
        # Group 1 is the optional directory, ending in the last path separator; group 2 is the stem.
        echo "$1" | sed -E 's#([^[:space:]]*[\\/])?([^[:space:]\\/]+)\.lib#-l\2#g'
    else
        echo "$1"
    fi
}

if [ "$from_installed_libraries" = true ]; then
    libdir="$(dirname "$filename")/../lib"
    lib_attributes="-L\${pcfiledir}/../lib"
    LC_COLLATE=C # same order in every locale
    for library in "$libdir"/lib*.a; do
        [ -e "$library" ] || { echo "Error: no static libraries in $libdir" >&2; exit 1; }
        name=$(basename "$library" .a)
        lib_attributes="$lib_attributes -l${name#lib}"
    done

    cflags="-I\${pcfiledir}/../include"
    for directory in "${extra_include_dirs[@]+"${extra_include_dirs[@]}"}"; do
        cflags="$cflags -I\${pcfiledir}/../$directory"
    done
else
    absolute_libdir=$(normalize_spaces "$(llvm-config --libdir)")
    system_libs=$(normalize_spaces "$(llvm-config --system-libs --libs core analysis bitwriter passes target all-targets)")
    lib_attributes=$(replace_with_relocatable_paths "-L${absolute_libdir} ${system_libs}")
    lib_attributes=$(convert_libs_to_spm_compatible_flags "$lib_attributes")

    # SwiftPM only accepts -I flags from pkg-config, so --cxxflags is not used.
    absolute_includedir=$(normalize_spaces "$(llvm-config --includedir)")
    cflags=$(replace_with_relocatable_paths "-I${absolute_includedir}")
fi

# Generate pkg-config content
echo Name: LLVM > "$filename"
echo Description: Low-level Virtual Machine compiler framework >> "$filename"
echo "Version: $(echo "${version}" | sed -E 's/^([0-9.]+).*/\1/')" >> "$filename"
echo URL: http://www.llvm.org/ >> "$filename"
echo Libs: ${lib_attributes} >> "$filename"
echo Cflags: ${cflags} >> "$filename"

echo "$filename written:"
cat "$filename"
