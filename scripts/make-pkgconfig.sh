#!/usr/bin/env bash

# Generates a relocatable pkg-config file (llvm.pc) describing the LLVM build that the
# `llvm-config` first found on PATH belongs to, and writes it to the given path.
#
# The set of LLVM components written into "Libs:" is hardcoded below; edit the `llvm-config
# --libs` invocation if you need a different set. On Windows (MSYS/MinGW/Cygwin shells) the
# ".lib" paths and bare ".lib" names that llvm-config emits are rewritten into -l flags, which
# is what SwiftPM expects; see https://github.com/hylo-lang/llvm-build/pull/36
#
# Parameters:
#   $1 - The path of the .pc file to write. Parent directories are created as needed.
#
# Requires:
#   - $1 must be in one directory below the LLVM installation prefix.
#
# Usage Example:
#   export PATH="/path/to/llvm/bin:$PATH"
#   ./make-pkgconfig.sh "$(llvm-config --prefix)/pkgconfig/llvm.pc"

set -e
set -o pipefail

if [ $# -ne 1 ]; then
    echo "Error: expected 1 argument, got $#" >&2
    echo "Usage: $0 <path-to-pc-file>" >&2
    exit 1
fi

if ! command -v llvm-config > /dev/null 2>&1; then
    echo "Error: 'llvm-config' was not found on PATH" >&2
    exit 1
fi

version=$(llvm-config --version)
filename=$1

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
    local input=$(normalize_path_separators "$1")
    local llvm_root=$(normalize_path_separators "$(llvm-config --prefix)")
    
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
    echo "$1" | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
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

# Get libraries
absolute_libdir=$(normalize_spaces "$(llvm-config --libdir)")
system_libs=$(normalize_spaces "$(llvm-config --system-libs --libs core analysis bitwriter passes target all-targets)")
lib_attributes=$(replace_with_relocatable_paths "-L${absolute_libdir} ${system_libs}")
lib_attributes=$(convert_libs_to_spm_compatible_flags "$lib_attributes")

# Get CXX flags
cxxflags_output=$(normalize_spaces "$(llvm-config --cxxflags)")
cflags=$(replace_with_relocatable_paths "$cxxflags_output")

# Generate pkg-config content
echo Name: LLVM > "$filename"
echo Description: Low-level Virtual Machine compiler framework >> "$filename"
echo Version: $(echo ${version} | sed 's/\([0-9.]\+\).*/\1/') >> "$filename"
echo URL: http://www.llvm.org/ >> "$filename"
echo Libs: ${lib_attributes} >> "$filename"
echo Cflags: ${cflags} >> "$filename"

echo "$filename written:"
cat "$filename"
