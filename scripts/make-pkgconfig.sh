#!/usr/bin/env bash
set -e
set -o pipefail

version=$(llvm-config --version)
filename=$1

mkdir -p $(dirname $filename)
touch $filename

# Outputs $1 with normalized path separators.
#
# Replaces backslashes with forward slashes.
normalize_path_separators() {
    echo "$1" | sed 's/\\/\//g'
}

# Outputs $1 with absolute paths replaced with relocatable paths.
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

# Outputs $1 with all contiguous white-space subsequences replaced with a single space,
# trimming at start and end.
normalize_spaces() {
    echo "$1" | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Outputs $1 with any MSVC-style library paths replaced with -l flags.
#
# On Windows, llvm-config --libs outputs full paths (e.g. C:\path\LLVMCore.lib)
# instead of -lLLVMCore. Convert them to -l flags for SPM compatibility.
#
# See https://github.com/hylo-lang/llvm-build/pull/36
convert_libs_to_flags() {
    local input="$1"
    local operating_system
    operating_system="$(uname -s)"
    if [[ "$operating_system" == MINGW* || "$operating_system" == MSYS* || "$operating_system" == CYGWIN* ]]; then
        echo "$input" | tr ' ' '\n' | sed 's|\\|/|g' | while read -r token; do
            if [[ "$token" == *.lib ]]; then
                local name
                name="$(basename "$token" .lib)"
                echo "-l${name}"
            else
                echo "$token"
            fi
        done | tr '\n' ' ' | sed 's/[[:space:]]*$//'
    else
        echo "$input"
    fi
}

# Get libraries
absolute_libdir=$(normalize_spaces "$(llvm-config --libdir)")
system_libs=$(normalize_spaces "$(llvm-config --system-libs --libs core analysis bitwriter passes target all-targets)")
system_libs=$(convert_libs_to_flags "$system_libs")
lib_attributes=$(replace_with_relocatable_paths "-L${absolute_libdir} ${system_libs}")

# Get CXX flags
cxxflags_output=$(normalize_spaces "$(llvm-config --cxxflags)")
cflags=$(replace_with_relocatable_paths "$cxxflags_output")

# Generate pkg-config content
echo Name: LLVM > $filename
echo Description: Low-level Virtual Machine compiler framework >> $filename
echo Version: $(echo ${version} | sed 's/\([0-9.]\+\).*/\1/') >> $filename
echo URL: http://www.llvm.org/ >> $filename
echo Libs: ${lib_attributes} >> $filename
echo Cflags: ${cflags} >> $filename

echo "$filename written:"
cat $filename
